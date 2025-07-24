{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "toggle-laptop-display" ''
      LAPTOP_EXISTS=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.name == "eDP-1") | .name' 2>/dev/null)
    
      if [ -n "$LAPTOP_EXISTS" ]; then
        # Laptop is on, switch to disable profile
        echo "Switching to laptop-disabled profile..."
        systemctl --user stop kanshi
        ${pkgs.hyprland}/bin/hyprctl keyword monitor "eDP-1,disable"
        systemctl --user start kanshi
      else
        # Laptop is off, switch to laptop-enabled profile
        echo "Switching to laptop-enabled profile..."
        systemctl --user stop kanshi
        ${pkgs.hyprland}/bin/hyprctl keyword monitor "eDP-1,1920x1080@60,5120x0,1"
    
        # Give kanshi time to see the new state, then it will match the laptop-enabled profile
        sleep 2
        systemctl --user start kanshi
      fi
    '')
  ];
}

