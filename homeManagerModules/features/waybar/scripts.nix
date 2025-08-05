{ pkgs }:

{
  waybar-battery = pkgs.writeShellScriptBin "waybar-battery" ''
    get_battery_info() {
      # Use the new CLI tool instead of D-Bus
      battery-thresholds status 2>/dev/null
    }

    case "$1" in
      status)
        info=$(get_battery_info)
        if echo "$info" | grep -q "BAT0:"; then
          # Parse the new format: "BAT0: 60% (Not charging) - ASUS: end=60%, mode=Balanced (80%)"
          capacity=$(echo "$info" | sed 's/.*BAT0: \([0-9]*\)%.*/\1/')
          status=$(echo "$info" | sed 's/.*(\([^)]*\)).*/\1/' | tr -d '\n\r')

          # Extract thresholds based on hardware type
          if echo "$info" | grep -q "ASUS:"; then
            start_thresh="N/A"
            end_thresh=$(echo "$info" | sed 's/.*end=\([0-9]*\)%.*/\1/')
          elif echo "$info" | grep -q "thresholds:"; then
            start_thresh=$(echo "$info" | sed 's/.*start=\([0-9]*\)%.*/\1/')
            end_thresh=$(echo "$info" | sed 's/.*end=\([0-9]*\)%.*/\1/')
          else
            start_thresh="N/A"
            end_thresh="N/A"
          fi
        else
          # Fallback to direct file reading
          capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
          status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null | tr -d '\n\r' || echo "Unknown")
          start_thresh="N/A"
          end_thresh=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "N/A")
        fi

        if ! [[ "$capacity" =~ ^[0-9]+$ ]]; then
          capacity="0"
        fi

        status=$(echo "$status" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ "$status" = "Charging" ]; then
          icon="󰂄"
        elif [ "$capacity" -gt 80 ]; then
          icon="󰁹"
        elif [ "$capacity" -gt 50 ]; then
          icon="󰂀"
        elif [ "$capacity" -gt 20 ]; then
          icon="󰁻"
        else
          icon="󰁺"
        fi

        echo "{\"text\":\"$icon $capacity%\",\"tooltip\":\"Battery: $capacity% ($status)\\nThresholds: $start_thresh%-$end_thresh%\\n\\nLeft click: Force charge\\nMiddle click: Restore defaults\\nRight click: Show status\",\"class\":\"battery\"}"
        ;;
      force)
        battery-thresholds force-charge
        if [ $? -eq 0 ]; then
          notify-send "Battery" "Forcing charge to 100%" -i battery-charging
        else
          notify-send "Battery Error" "Failed to force charge" -i dialog-error
        fi
        ;;
      restore)
        battery-thresholds restore
        if [ $? -eq 0 ]; then
          notify-send "Battery" "Restored to default thresholds (40%-60%)" -i battery
        else
          notify-send "Battery Error" "Failed to restore defaults" -i dialog-error
        fi
        ;;
      status-popup)
        status_info=$(battery-thresholds status)
        notify-send "Battery Status" "$status_info" -i battery -t 5000
        ;;
    esac
  '';
  waybar-microphone = pkgs.writeShellScriptBin "waybar-microphone" ''
    # Get microphone status using wpctl (PipeWire)
    if wpctl get-volume 55 | grep -q MUTED; then
      echo "󰍭 MUTED"
    else
      vol=$(wpctl get-volume 55 | awk '{print int($2*100)}')
      echo "󰍬 $vol%"
    fi
  '';

  waybar-microphone-toggle = pkgs.writeShellScriptBin "waybar-microphone-toggle" ''
    wpctl set-mute 55 toggle
  '';

  waybar-microphone-volume-up = pkgs.writeShellScriptBin "waybar-microphone-volume-up" ''
    wpctl set-volume 55 5%+
  '';

  waybar-microphone-volume-down = pkgs.writeShellScriptBin "waybar-microphone-volume-down" ''
    wpctl set-volume 55 5%-
  '';
}

