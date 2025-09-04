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
          echo "Kanshi active, disabling laptop display"
          MONITORS_JSON=$(${pkgs.hyprland}/bin/hyprctl monitors -j)
          LAPTOP_DISPLAY=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r '[.[] | select(.name | startswith("eDP-")) | .name] | first')
          echo "Laptop display: $LAPTOP_DISPLAY"
          OTHER_DISPLAYS=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq -r '[.[] | select(.name | startswith("eDP-") | not) | .name] | join(" ")')
          if [ -z "$OTHER_DISPLAYS" ]; then
            echo "SAFETY: No other displays, cannot disable"
            exit 1
          fi
          echo "Other displays: $OTHER_DISPLAYS"
          MIN_X=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq '[.[] | select(.name | startswith("eDP-") | not) | .x] | min')
          MIN_Y=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq '[.[] | select(.name | startswith("eDP-") | not) | .y] | min')
          systemctl --user stop kanshi
          ${pkgs.hyprland}/bin/hyprctl keyword monitor "$LAPTOP_DISPLAY,disable"
          for OTHER in $OTHER_DISPLAYS; do
            THIS_JSON=$(echo "$MONITORS_JSON" | ${pkgs.jq}/bin/jq ".[] | select(.name == \"$OTHER\")")
            WIDTH=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.width')
            HEIGHT=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.height')
            REFRESH=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.refreshRate | round')
            SCALE=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.scale')
            TRANSFORM=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.transform')
            X=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.x')
            Y=$(echo "$THIS_JSON" | ${pkgs.jq}/bin/jq -r '.y')
            NEW_X=$((X - MIN_X))
            NEW_Y=$((Y - MIN_Y))
            MODE="''${WIDTH}x''${HEIGHT}@''${REFRESH}"
            POS="''${NEW_X}x''${NEW_Y}"
            ${pkgs.hyprland}/bin/hyprctl keyword monitor "$OTHER,$MODE,$POS,$SCALE,transform,$TRANSFORM"
          done
        else
          echo "Kanshi inactive, starting kanshi"
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
    ];
  };
}
