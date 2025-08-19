{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.sunshine;

  sunshineStream = pkgs.writeShellScript "sunshine-headless" ''
    echo "Setting up headless display for Sunshine streaming..."

    while ! ${pkgs.hyprland}/bin/hyprctl version >/dev/null 2>&1; do
      sleep 0.1
    done

    # Step 1: Create headless display
    ${pkgs.hyprland}/bin/hyprctl output add headless sunshine-ultrawide

    # Step 2: Toggle laptop display OFF if autoToggleLaptop is enabled
    ${if cfg.autoToggleLaptop then ''
      echo "Toggling laptop display off for streaming..."
      toggle-laptop-display
    '' else ''
      echo "Skipping laptop display toggle (autoToggleLaptop disabled)"
    ''}

    # Wait for display change to complete
    sleep 3

    mkdir -p ~/.config/sunshine
    cat > ~/.config/sunshine/sunshine.conf << 'EOF'
output_name = 1
av1_mode = 2
hevc_mode = 1
encoder = vaapi
vaapi_strict_rc_buffer = enabled

# local phone hotspot optimizations
max_bitrate = 25000
fec_percentage = 20
lan_encryption_mode = 0 # BE SURE ON OWN LOCAL NETWORK
qp = 28
EOF

    echo "Starting Sunshine with discrete GPU and optimized encoding settings..."

    ${pkgs.sunshine}/bin/sunshine &

    SUNSHINE_PID=$!

    echo "Sunshine started with AV1 enabled, HEVC disabled, and local hotspot optimizations."
    echo "Web interface: https://localhost:47990"

    cleanup() {
      echo "Cleaning up..."
      kill $SUNSHINE_PID 2>/dev/null || true

      # Step 3: Restart kanshi to restore laptop display and handle configuration
      echo "Restarting kanshi to restore display configuration..."
      systemctl --user restart kanshi

      # Wait for kanshi to stabilize displays
      sleep 2

      # Step 4: Destroy headless display
      ${pkgs.hyprland}/bin/hyprctl output destroy sunshine-ultrawide >/dev/null 2>&1 || true
      rm -f ~/.config/sunshine/sunshine.conf

      echo "Sunshine streaming stopped and kanshi restarted."
    }

    trap cleanup EXIT INT TERM
    wait $SUNSHINE_PID
  '';

in {
  options.myNixOS.sunshine = {
    autoToggleLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically toggle laptop display off during streaming and back on during cleanup";
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

    networking.firewall = {
      allowedTCPPorts = [ 47989 47984 47990 48010 ];
      allowedUDPPorts = [ 47998 47999 48000 48010 ];
    };
  };
}
