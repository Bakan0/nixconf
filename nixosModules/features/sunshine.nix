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
# DEBUG: If AV1 not working despite av1_mode=0, check client codec preference
# (e.g., Moonlight: set to "prefer AV1" not "automatic")
${if config.myNixOS.amd.enable or false then ''
# AMD AMF encoder settings (hardware-accelerated with better quality control)
encoder = amdvce
amd_usage = transcoding
amd_rc = vbr_peak
amd_quality = quality
amd_vbaq = enabled
'' else ''
# VA-API encoder settings (fallback for non-AMD systems)
encoder = vaapi
vaapi_strict_rc_buffer = enabled
''}



${if cfg.lowPower then ''
# Conservative settings for battery/thermal constrained environments
max_bitrate = 25000
fec_percentage = 20
qp = 28
'' else ''
# High-performance settings optimized for modern hardware (OnePlus 12 Pro / Snapdragon 8 Gen 3)
# Text quality optimization: lower QP for better quality
max_bitrate = 80000
fec_percentage = 25
qp = 8
''}
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

    echo "Starting Sunshine with optimal GPU and encoding settings..."

    # Auto-detect best GPU for hardware encoding (works on any hardware)
    DISCRETE_PRIME=""
    for i in 0 1 2 3; do
      if DRI_PRIME=$i ${pkgs.glxinfo}/bin/glxinfo >/dev/null 2>&1; then
        renderer=$(DRI_PRIME=$i ${pkgs.glxinfo}/bin/glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
        # Check if this looks like discrete GPU (AMD RX/Radeon, NVIDIA GTX/RTX, Intel Arc)
        if echo "$renderer" | grep -qE "(RX [67][0-9][0-9][0-9]|GTX [1-4][0-9][0-9][0-9]|RTX [2-4][0-9][0-9][0-9]|Arc A[0-9]|Navi [12][0-9])"; then
          DISCRETE_PRIME=$i
          echo "Detected discrete GPU: $renderer (DRI_PRIME=$i)"
          break
        fi
      fi
    done

    if [ -n "$DISCRETE_PRIME" ]; then
      export DRI_PRIME="$DISCRETE_PRIME"
      export __GLX_VENDOR_LIBRARY_NAME=mesa
      echo "Using discrete GPU for hardware encoding"
    else
      echo "No discrete GPU detected, using system default"
    fi
    
    ${pkgs.sunshine}/bin/sunshine &

    SUNSHINE_PID=$!

    echo "Sunshine started with encoding optimizations enabled."
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
  options.myNixOS.sunshine = {
    autoToggleLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically toggle laptop display off during streaming and back on during cleanup";
    };
    
    lowPower = mkOption {
      type = types.bool;
      default = false;
      description = "Enable conservative settings for battery/thermal constrained environments";
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
