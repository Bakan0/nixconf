{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.sunshine-hyprland;

  sunshineStream = pkgs.writeShellScript "sunshine-headless" ''
    echo "Setting up headless display for Sunshine streaming..."

    while ! ${pkgs.hyprland}/bin/hyprctl version >/dev/null 2>&1; do
      sleep 0.1
    done

    # Step 1: Create headless display
    ${pkgs.hyprland}/bin/hyprctl output add headless sunshine-ultrawide

    # Step 1.5: Wait for display to be ready then move workspaces > 1 to headless display
    sleep 2
    echo "Moving workspaces 2+ to sunshine-ultrawide for streaming..."
    for workspace in {2..10}; do
      ${pkgs.hyprland}/bin/hyprctl dispatch moveworkspacetomonitor "$workspace" sunshine-ultrawide 2>/dev/null || true
    done

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
vaapi_strict_rc_buffer = enabled
hevc_mode = 1
EOF

    # Create clean apps.json with only Desktop (removes useless Low Res Desktop with xrandr)
    chmod +w ~/.config/sunshine/apps.json 2>/dev/null || true
    cat > ~/.config/sunshine/apps.json << 'EOF'
{
  "env": {
    "PATH": "$(PATH):$(HOME)/.local/bin"
  },
  "apps": [
    {
      "name": "Desktop",
      "image-path": "desktop.png"
    }
  ]
}
EOF

    echo "Starting Sunshine with discrete GPU and optimized encoding settings..."

    # Set environment variables for consistent hybrid GPU usage
    export DRI_PRIME=1
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export AMD_VULKAN_ICD=RADV
    export RADV_PERFTEST=aco
    export LIBVA_DRIVER_NAME=radeonsi
    export VDPAU_DRIVER=radeonsi

    ${pkgs.sunshine}/bin/sunshine &

    SUNSHINE_PID=$!

    echo "Sunshine started with H.264 only (near-lossless), AV1/HEVC disabled, and local hotspot optimizations."
    echo "Web interface: https://localhost:47990"

    # Create temporary Avahi service for 3 minutes to allow Quest discovery
    echo "Creating temporary mDNS advertisement for 3 minutes..."
    
    avahi-publish-service -s "$(hostname) Sunshine" _nvstream._tcp 47989 \
      "uuid=$(cat /proc/sys/kernel/random/uuid | tr -d '-')" \
      "version=7" \
      "localname=$(hostname)" &
    
    AVAHI_PID=$!
    
    # Remove service advertisement after 3 minutes
    (sleep 180 && kill $AVAHI_PID 2>/dev/null && echo "mDNS advertisement removed") &

    cleanup() {
      echo "Cleaning up..."
      kill $SUNSHINE_PID 2>/dev/null || true
      kill $AVAHI_PID 2>/dev/null || true

      # Step 3: Restart kanshi to restore laptop display and handle configuration
      echo "Restarting kanshi to restore display configuration..."
      systemctl --user restart kanshi

      # Wait for kanshi to stabilize displays
      sleep 2

      # Step 4: Destroy headless display
      ${pkgs.hyprland}/bin/hyprctl output destroy sunshine-ultrawide >/dev/null 2>&1 || true
      rm -f ~/.config/sunshine/sunshine.conf
      rm -f ~/.config/sunshine/apps.json

      echo "Sunshine streaming stopped and kanshi restarted."
    }

    trap cleanup EXIT INT TERM
    wait $SUNSHINE_PID
  '';

in {
  options.myNixOS.sunshine-hyprland = {
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
