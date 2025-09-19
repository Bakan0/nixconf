{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.kanshi;
in {
  config = mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "toggle-laptop-display" ''
        #!/usr/bin/env bash

        echo "=== LAPTOP DISPLAY TOGGLE ==="

        KANSHI_STATUS=$(systemctl --user is-active kanshi)

        if [ "$KANSHI_STATUS" = "active" ]; then
          echo "Kanshi active, stopping kanshi and enabling laptop display"

          # Capture current monitor configurations BEFORE stopping kanshi
          MONITORS_JSON=$(${pkgs.hyprland}/bin/hyprctl monitors -j)
          echo "Captured current monitor configurations"

          # Stop kanshi FIRST
          systemctl --user stop kanshi

          # Find embedded display interface from /sys/class/drm/ (eDP, eHDMI, etc.)
          LAPTOP_DISPLAY=""
          for drm_dev in /sys/class/drm/card*/card*-e*; do
            if [ -e "$drm_dev" ]; then
              LAPTOP_DISPLAY=$(basename "$drm_dev" | sed 's/card[0-9]*-//')
              echo "Found embedded display: $LAPTOP_DISPLAY"
              break
            fi
          done

          if [ -z "$LAPTOP_DISPLAY" ]; then
            echo "ERROR: Could not find embedded display interface"
            exit 1
          fi

          # Enable laptop display using the configured resolution and scale
          ${pkgs.hyprland}/bin/hyprctl keyword monitor "$LAPTOP_DISPLAY,${cfg.laptopResolution},0x0,${toString cfg.laptopScale}"

          # Reapply existing monitor configurations from before kanshi was stopped
          echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -c '.[]' | while read -r monitor; do
            NAME=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.name')
            WIDTH=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.width')
            HEIGHT=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.height')
            REFRESH=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.refreshRate | round')
            SCALE=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.scale')
            TRANSFORM=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.transform')
            X=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.x')
            Y=$(echo "$monitor" | ${pkgs.jq}/bin/jq -r '.y')

            # Skip the laptop display (already handled above)
            if [[ "$NAME" == "$LAPTOP_DISPLAY" ]]; then
              continue
            fi

            MODE="''${WIDTH}x''${HEIGHT}@''${REFRESH}"
            POS="''${X}x''${Y}"
            echo "Reapplying: $NAME at $MODE, position $POS, scale $SCALE, transform $TRANSFORM"
            ${pkgs.hyprland}/bin/hyprctl keyword monitor "$NAME,$MODE,$POS,$SCALE,transform,$TRANSFORM"
          done
        else
          echo "Kanshi inactive, starting kanshi (will disable laptop display)"
          systemctl --user start kanshi
        fi

        echo "=== TOGGLE COMPLETE ==="
      '')
      
      (pkgs.writeShellScriptBin "toggle-dpms" ''
        #!/usr/bin/env bash

        echo "=== DPMS TOGGLE ==="
        
        # Query current DPMS status from hyprctl
        MONITORS_STATUS=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[0].dpmsStatus')
        
        if [ "$MONITORS_STATUS" = "true" ]; then
          # Displays are on, turn them off
          echo "Turning displays OFF..."
          ${pkgs.hyprland}/bin/hyprctl dispatch dpms off
          echo "Displays turned OFF"
        else
          # Displays are off, turn them on  
          echo "Turning displays ON..."
          ${pkgs.hyprland}/bin/hyprctl dispatch dpms on
          echo "Displays turned ON"
        fi

        echo "=== DPMS TOGGLE COMPLETE ==="
      '')
      
      # Reset Hyprland XDG portals to fix screen sharing conflicts
      (pkgs.writeShellScriptBin "hyprland-portal-reset" ''
        #!/usr/bin/env bash

        echo "🔄 Resetting Hyprland XDG portals to fix screen sharing conflicts..."
        
        # Stop portal services
        echo "Stopping portal services..."
        systemctl --user stop xdg-desktop-portal.service 2>/dev/null || true
        systemctl --user stop xdg-desktop-portal-hyprland.service 2>/dev/null || true
        
        # Wait for cleanup
        sleep 2
        
        # Restart portal services
        echo "Restarting portal services..."
        systemctl --user start xdg-desktop-portal.service
        systemctl --user start xdg-desktop-portal-hyprland.service
        
        echo "✅ Portal services restarted. Screen sharing should work now!"
        echo "   Try your screen sharing operation again."
      '')
    ];
  };
}
