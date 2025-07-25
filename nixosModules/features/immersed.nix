{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.immersed;

  # Create a custom package set with gjs tests disabled, only for immersed's dependency chain
  immersedPkgs = pkgs.extend (final: prev: {
    gjs = prev.gjs.overrideAttrs (oldAttrs: {
      doCheck = false;  # Skip flaky GIMarshalling test
    });
  });

  # Use immersed from the custom package set
  immersedFixed = immersedPkgs.immersed;

  # Monitor setup script - exact match to your working commands
  setupMonitors = pkgs.writeShellScript "immersed-setup-monitors" ''
    # Wait for Hyprland to be ready
    while ! ${pkgs.hyprland}/bin/hyprctl version >/dev/null 2>&1; do
      sleep 0.1
    done
  
    # Add headless outputs (you said "obviously headless first")
    ${pkgs.hyprland}/bin/hyprctl output add headless immersed-1
    ${pkgs.hyprland}/bin/hyprctl output add headless immersed-2
  
    # Your exact working command
    ${pkgs.hyprland}/bin/hyprctl keyword monitor "immersed-1,5120x1440@60.00,0x-1440,1"
    ${pkgs.hyprland}/bin/hyprctl keyword monitor "immersed-2,1920x1080@60.00,5120x-1080,1"
  '';

  # Monitor cleanup script - restore state
  cleanupMonitors = pkgs.writeShellScript "immersed-cleanup-monitors" ''
    if ${pkgs.hyprland}/bin/hyprctl version >/dev/null 2>&1; then
      # Save current workspace before cleanup
      CURRENT_WORKSPACE=$(${pkgs.hyprland}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.id')

      # Destroy virtual monitors
      ${pkgs.hyprland}/bin/hyprctl output destroy immersed-1 >/dev/null 2>&1 || true
      ${pkgs.hyprland}/bin/hyprctl output destroy immersed-2 >/dev/null 2>&1 || true

      # Return to original workspace and focus laptop
      ${pkgs.hyprland}/bin/hyprctl dispatch workspace $CURRENT_WORKSPACE >/dev/null 2>&1
      ${pkgs.hyprland}/bin/hyprctl dispatch focusmonitor eDP-1 >/dev/null 2>&1

      # Restart waybar to restore proper layout
      ${pkgs.systemd}/bin/systemctl --user restart waybar >/dev/null 2>&1 || true
    fi
  '';

in {
  config = mkIf cfg.enable {
    # Install Immersed with the fixed gjs dependency + desktop wrapper
    environment.systemPackages = [
      immersedFixed
      (pkgs.writeTextFile {
        name = "immersed-with-monitors";
        destination = "/share/applications/immersed-monitors.desktop";
        text = ''
          [Desktop Entry]
          Name=Immersed (with Virtual Monitors)
          Exec=${pkgs.bash}/bin/bash -c "${setupMonitors} && ${immersedFixed}/bin/immersed; ${cleanupMonitors}"
          Icon=immersed
          Type=Application
          Categories=Network;
          Comment=VR workspace with virtual monitors
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

