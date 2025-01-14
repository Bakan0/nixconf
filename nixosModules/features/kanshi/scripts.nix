{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "toggle-laptop-display" ''
      # Stop kanshi temporarily
      ${pkgs.systemd}/bin/systemctl --user stop kanshi

      # Get monitor states using jq
      MONITOR_INFO=$(${pkgs.hyprland}/bin/hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.name == "eDP-1")')
      EDP_DPMS=$(echo "$MONITOR_INFO" | ${pkgs.jq}/bin/jq -r '.dpmsStatus')

      # Normalize DPMS state
      if [ -z "$EDP_DPMS" ] || [ "$EDP_DPMS" = "false" ]; then
        EDP_STATE="off"
      else
        EDP_STATE="on"
      fi

      if [ "$EDP_STATE" = "on" ]; then
        # Turn laptop display off
        ${pkgs.hyprland}/bin/hyprctl keyword monitor eDP-1,disable
        sleep 0.3
        ${pkgs.hyprland}/bin/hyprctl dispatch dpms off eDP-1
        # Set ultrawide resolution
        ${pkgs.hyprland}/bin/hyprctl keyword monitor "DP-1,5120x1440@29.979,0x0,1"
      else
        # Turn laptop display on
        ${pkgs.hyprland}/bin/hyprctl dispatch dpms on eDP-1
        sleep 0.3
        # Changed position to 5120x0 to put laptop on the right
        ${pkgs.hyprland}/bin/hyprctl keyword monitor "eDP-1,1920x1080@60,5120x0,1"
        # Set ultrawide resolution at origin
        ${pkgs.hyprland}/bin/hyprctl keyword monitor "DP-1,5120x1440@29.979,0x0,1"
      fi

      # Restart kanshi
      sleep 0.5
      ${pkgs.systemd}/bin/systemctl --user start kanshi
    '')
  ];
}
