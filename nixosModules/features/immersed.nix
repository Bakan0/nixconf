{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.immersed;

  # Create a custom package set with gjs tests disabled, only for immersed's dependency chain
  # immersedPkgs = pkgs.extend (final: prev: {
  #   gjs = prev.gjs.overrideAttrs (oldAttrs: {
  #     doCheck = false;  # Skip flaky GIMarshalling test
  #   });
  # });

  # Use immersed from the custom package set
  # immersedFixed = immersedPkgs.immersed;

  # Create a fixed immersed package that wraps with proper library paths
  immersedFixed = pkgs.immersed.overrideAttrs (oldAttrs: {
    postFixup = (oldAttrs.postFixup or "") + ''
      # Fix pixman/cairo library compatibility by wrapping with correct library paths
      wrapProgram $out/bin/immersed \
        --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath [
          pkgs.pixman
          pkgs.cairo
          pkgs.glib
          pkgs.libselinux
        ]}
    '';
  });

  immersedStream = pkgs.writeShellScript "immersed-headless" ''
    echo "Setting up headless displays..."

    while ! ${pkgs.hyprland}/bin/hyprctl version >/dev/null 2>&1; do
      sleep 0.1
    done

    # Step 1: Create headless displays
    ${pkgs.hyprland}/bin/hyprctl output add headless immersed-1
    ${pkgs.hyprland}/bin/hyprctl output add headless immersed-2

    # Step 1.5: Wait for displays to be ready then move workspaces to virtual displays
    sleep 2
    echo "Moving workspaces 2+ to immersed-1..."
    for workspace in {2..10}; do
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor "$workspace" immersed-1 2>/dev/null || true
    done

    # Step 1.6: Move workspace 6 specifically to immersed-2 (for work PWAs)
    echo "Moving workspace 6 to immersed-2..."
    ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor "6" immersed-2 2>/dev/null || true
    
    # Step 1.6.1: Move any existing PWA windows to workspace 6 (which is now on immersed-2)
    echo "Moving existing PWA windows to workspace 6..."
    ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspace 6,title:.*Outlook.* 2>/dev/null || true
    ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspace 6,title:.*Teams.* 2>/dev/null || true

    # Step 1.7: Ensure Immersed apps stay on workspace 1 (laptop monitor)
    echo "Moving Immersed apps back to workspace 1..."
    ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent 1,class:Immersed 2>/dev/null || true
    ${pkgs.hyprland}/bin/hyprctl dispatch movetoworkspacesilent 1,title:Immersed Workspace 2>/dev/null || true

    # Step 2: Toggle laptop display OFF if autoToggleLaptop is enabled
    ${if cfg.autoToggleLaptop then ''
      echo "Toggling laptop display off..."
      toggle-laptop-display
    '' else ''
      echo "Skipping laptop display toggle"
    ''}

    # Wait for display change to complete
    sleep 3


    echo "Starting Immersed..."

    ${immersedFixed}/bin/immersed &

    IMMERSED_PID=$!

    echo "Immersed started"
    
    # Clean up portal conflicts created during startup
    sleep 2
    hyprland-portal-reset

    # Auto-start work apps if workMode is configured
    ${optionalString (cfg.workMode == "work") ''
      echo "Starting work apps..."
      sleep 5  # Wait for Immersed to fully initialize

      # Move to workspace 6 on immersed-2 and start Edge PWAs
      ${pkgs.hyprland}/bin/hyprctl dispatch workspace 6
      ${pkgs.hyprland}/bin/hyprctl dispatch focusmonitor immersed-2

      # Start Edge PWAs for work
      ${pkgs.microsoft-edge}/bin/microsoft-edge --app-id=_famdcdojlmjefmhdpbpmekhodagkodei &  # Outlook PWA
      sleep 2
      ${pkgs.microsoft-edge}/bin/microsoft-edge --app-id=_ckdeglopgbdgpkmhnmkigpfgebcdbanf &  # Microsoft Teams PWA

      echo "Work apps started"
    ''}

    cleanup() {
      echo "Cleaning up..."
      kill $IMMERSED_PID 2>/dev/null || true

      # Step 3: Restart kanshi to restore laptop display and handle configuration
      echo "Restarting kanshi..."
      systemctl --user restart kanshi

      # Wait for kanshi to stabilize displays
      sleep 2

      # Step 4: Destroy headless displays
      ${pkgs.hyprland}/bin/hyprctl output destroy immersed-1 >/dev/null 2>&1 || true
      ${pkgs.hyprland}/bin/hyprctl output destroy immersed-2 >/dev/null 2>&1 || true

      # Final portal cleanup to clear any accumulated session conflicts
      hyprland-portal-reset

      # Keep config file to preserve authentication (don't clean it up)
      echo "Immersed stopped, config preserved"
    }

    trap cleanup EXIT INT TERM
    wait $IMMERSED_PID
  '';

in {
  options.myNixOS.immersed = {
    autoToggleLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically toggle laptop display off during streaming and back on during cleanup";
    };
    
    workMode = mkOption {
      type = types.nullOr (types.enum [ "work" ]);
      default = null;
      description = "Work mode for auto-starting work apps on workspace 6 (immersed-2)";
    };
  };

  config = mkIf cfg.enable {
    # Install Immersed with library compatibility fixes + desktop wrapper
    environment.systemPackages = [
      immersedFixed
      (pkgs.writeShellScriptBin "immersed-headless" ''exec ${immersedStream}'')
      (pkgs.writeTextFile {
        name = "immersed-headless-desktop";
        destination = "/share/applications/immersed-headless.desktop";
        text = ''
          [Desktop Entry]
          Name=Immersed (Headless)
          Exec=${immersedStream}
          Icon=immersed
          Type=Application
          Categories=Network;VR;
          Comment=Stream headless displays via Immersed
          Terminal=false
          StartupNotify=false
        '';
      })
    ];

    # Enable required services for VR/AR applications
    hardware.graphics = {
      enable = true;
      enable32Bit = true;  # Required for some VR applications
    };

    # Enable required system services
    services.dbus.enable = true;

    # Ensure required desktop integration
    services.xserver.enable = mkDefault true;  # Still needed for some desktop integration

    # Add VR-related environment variables
    environment.variables = {
      # Ensure proper VR runtime detection
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  };
}

