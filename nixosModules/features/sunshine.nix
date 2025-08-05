# nixosModules/features/sunshine.nix
{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.sunshine;

  # Smart positioning calculation
  calculatePosition = resolution: 
    let
      # Parse resolution (e.g., "3104x1664" -> width=3104, height=1664)
      parts = builtins.split "x" resolution;
      width = builtins.elemAt parts 0;
      height = builtins.elemAt parts 2;

      # Laptop screen specs
      laptopWidth = 1920;
      laptopHeight = 1200;

      # Calculate centered position above laptop
      # X: Center headless display above laptop screen
      centerX = (laptopWidth - (builtins.fromJSON width)) / 2;
      # Y: Position above laptop (negative Y moves up)
      posY = -(builtins.fromJSON height);
    in
      "${toString (builtins.floor centerX)}x${toString posY}";

  # Get the resolution to use
  activeResolution = if cfg.customResolution != null then cfg.customResolution else cfg.resolution;

  # Calculate smart position
  smartPosition = calculatePosition activeResolution;

  sunshineStream = pkgs.writeShellScript "sunshine-headless" ''
    echo "Setting up headless display for Sunshine streaming..."

    # Wait for Hyprland to be ready
    while ! ${pkgs.hyprland}/bin/hyprctl version >/dev/null 2>&1; do
      sleep 0.1
    done

    # Create headless display
    ${pkgs.hyprland}/bin/hyprctl output add headless sunshine-ultrawide

    # Configure headless display (auto-centered above laptop screen)
    ${pkgs.hyprland}/bin/hyprctl keyword monitor "sunshine-ultrawide,${activeResolution}@60.00,${smartPosition},${cfg.scale}"

    # Fix laptop screen position to be properly aligned
    ${pkgs.hyprland}/bin/hyprctl keyword monitor "eDP-1,1920x1200@165.00,960x0,1"

    echo "Headless display configured: ${activeResolution} at ${smartPosition} (scale ${cfg.scale})"
    echo "Laptop screen repositioned to: 960x0"

    # Give Hyprland time to register the display changes
    sleep 3

    # Create sunshine config with monitor selection
    mkdir -p ~/.config/sunshine
    cat > ~/.config/sunshine/sunshine.conf << 'EOF'
output_name = 1
EOF

    echo "Starting Sunshine with discrete GPU and monitor 1 selection..."

    # Launch sunshine with discrete GPU
    DRI_PRIME=1 ${pkgs.sunshine}/bin/sunshine &
    SUNSHINE_PID=$!

    echo "Sunshine started! Monitor 1 (sunshine-ultrawide) should be selected."
    echo "Web interface: https://localhost:47990"

    # Cleanup function
    cleanup() {
      echo "Cleaning up..."
      kill $SUNSHINE_PID 2>/dev/null || true
      ${pkgs.hyprland}/bin/hyprctl output destroy sunshine-ultrawide >/dev/null 2>&1 || true
      # Reset laptop screen to original position
      ${pkgs.hyprland}/bin/hyprctl keyword monitor "eDP-1,1920x1200@165.00,0x0,1" >/dev/null 2>&1 || true
      rm -f ~/.config/sunshine/sunshine.conf
      echo "Sunshine streaming stopped."
    }

    # Setup cleanup on exit
    trap cleanup EXIT INT TERM

    # Wait for sunshine to finish
    wait $SUNSHINE_PID
  '';

in {
  options.myNixOS.sunshine = {
    resolution = mkOption {
      type = types.str;
      default = "3104x1664";  # Lower Meta Quest Native - optimal performance
      description = "Resolution for headless display";
    };

    scale = mkOption {
      type = types.str;
      default = "1.0";  # Native scale for VR resolution
      description = "Scale factor for headless display";
    };

    customResolution = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "4128x2208";
      description = "Custom resolution for headless display (overrides default)";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.sunshine
      (pkgs.writeShellScriptBin "sunshine-headless" ''exec ${sunshineStream}'')
      (pkgs.writeTextFile {
        name = "sunshine-headless-desktop";
        destination = "/share/applications/sunshine-headless.desktop";
        text = ''
          [Desktop Entry]
          Name=Sunshine (Headless)
          Exec=${sunshineStream}
          Icon=video-display
          Type=Application
          Categories=Network;Game;
          Comment=Stream headless display via Sunshine
          Terminal=false
          StartupNotify=false
        '';
      })
    ];

    # Firewall configuration for Sunshine
    networking.firewall = {
      allowedTCPPorts = [
        47989  # Sunshine HTTPS Web UI
        47984  # Sunshine HTTP Web UI  
        47990  # Sunshine RTSP
        48010  # Sunshine additional TCP
      ];
      allowedUDPPorts = [
        47998  # Sunshine Video
        47999  # Sunshine Control
        48000  # Sunshine Audio
        48010  # Sunshine Mic (if needed)
      ];
    };
  };
}

