{ pkgs }:

{
  waybar-battery = pkgs.writeShellScriptBin "waybar-battery" ''
    get_battery_info() {
      dbus-send --system --print-reply --dest=org.nixos.BatteryManager \
        /org/nixos/BatteryManager org.nixos.BatteryManager.GetStatus 2>/dev/null
    }

    case "$1" in
      status)
        # ... keep your existing status code exactly the same ...
        info=$(get_battery_info)
        if echo "$info" | grep -q "capacity"; then
          capacity=$(echo "$info" | grep -A1 '"capacity"' | grep 'int32' | sed 's/.*int32 \([0-9]*\).*/\1/')
          status=$(echo "$info" | grep -A1 '"status"' | grep 'string' | sed 's/.*string "\([^"]*\)".*/\1/' | tr -d '\n\r')
          start_thresh=$(echo "$info" | grep -A1 '"start_threshold"' | grep 'int32' | sed 's/.*int32 \([0-9]*\).*/\1/')
          end_thresh=$(echo "$info" | grep -A1 '"end_threshold"' | grep 'int32' | sed 's/.*int32 \([0-9]*\).*/\1/')
        else
          capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
          status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null | tr -d '\n\r' || echo "Unknown")
          start_thresh=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo "N/A")
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
        result=$(dbus-send --system --print-reply --dest=org.nixos.BatteryManager /org/nixos/BatteryManager org.nixos.BatteryManager.ForceCharge 2>&1)
        if echo "$result" | grep -q "boolean true"; then
          notify-send "Battery" "Forcing charge to 100%" -i battery-charging
        else
          notify-send "Battery Error" "Failed to force charge: $result" -i dialog-error
        fi
        ;;
      restore)
        result=$(dbus-send --system --print-reply --dest=org.nixos.BatteryManager /org/nixos/BatteryManager org.nixos.BatteryManager.RestoreDefaults 2>&1)
        if echo "$result" | grep -q "boolean true"; then
          notify-send "Battery" "Restored to default thresholds (40%-60%)" -i battery
        else
          notify-send "Battery Error" "Failed to restore defaults: $result" -i dialog-error
        fi
        ;;
      status-popup)
        status_info=$(battery-thresholds status)
        notify-send "Battery Status" "$status_info" -i battery -t 5000
        ;;
    esac
  '';
}

