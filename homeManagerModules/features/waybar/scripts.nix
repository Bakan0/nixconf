{ pkgs }:

{
  waybar-battery = pkgs.writeShellScriptBin "waybar-battery" ''
    get_battery_info() {
      dbus-send --system --print-reply --dest=org.nixos.BatteryManager \
        /org/nixos/BatteryManager org.nixos.BatteryManager.GetStatus 2>/dev/null
    }

    case "$1" in
      status)
        # Try D-Bus first, fallback to direct file reading
        info=$(get_battery_info)
        if echo "$info" | grep -q "capacity"; then
          # Parse D-Bus output - improved parsing
          capacity=$(echo "$info" | grep -A1 '"capacity"' | grep 'int32' | sed 's/.*int32 \([0-9]*\).*/\1/')
          status=$(echo "$info" | grep -A1 '"status"' | grep 'string' | sed 's/.*string "\([^"]*\)".*/\1/' | tr -d '\n\r')
          start_thresh=$(echo "$info" | grep -A1 '"start_threshold"' | grep 'int32' | sed 's/.*int32 \([0-9]*\).*/\1/')
          end_thresh=$(echo "$info" | grep -A1 '"end_threshold"' | grep 'int32' | sed 's/.*int32 \([0-9]*\).*/\1/')
        else
          # Fallback to direct file reading
          capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "0")
          status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null | tr -d '\n\r' || echo "Unknown")
          start_thresh=$(cat /sys/class/power_supply/BAT0/charge_control_start_threshold 2>/dev/null || echo "N/A")
          end_thresh=$(cat /sys/class/power_supply/BAT0/charge_control_end_threshold 2>/dev/null || echo "N/A")
        fi

        # Validate we got numbers
        if ! [[ "$capacity" =~ ^[0-9]+$ ]]; then
          capacity="0"
        fi

        # Clean up status string - remove any whitespace/newlines
        status=$(echo "$status" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Determine icon based on status and capacity
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

        echo "{\"text\":\"$icon $capacity%\",\"tooltip\":\"Battery: $capacity% ($status)\\nThresholds: $start_thresh%-$end_thresh%\",\"class\":\"battery\"}"
        ;;
      menu)
        # Show rofi menu with top-right positioning
        choice=$(echo -e "󰃨 Status\n󱐋 Force Charge (100%)\n󰂄 Restore Defaults\n󰒓 Custom Settings" | \
          rofi -dmenu -i -p "Battery Management" \
          -theme-str 'window { location: northeast; anchor: northeast; x-offset: -10px; y-offset: 10px; width: 500px; }')

        case "$choice" in
          "󰃨 Status")
            battery-thresholds status | sed 's/ - /\n  /' | \
              rofi -dmenu -i -p "Battery Status" \
              -theme-str 'window { location: northeast; anchor: northeast; x-offset: -10px; y-offset: 10px; width: 500px; }' \
              -lines 3
            ;;
          "󱐋 Force Charge (100%)")
            result=$(dbus-send --system --print-reply --dest=org.nixos.BatteryManager /org/nixos/BatteryManager org.nixos.BatteryManager.ForceCharge 2>&1)
            if echo "$result" | grep -q "boolean true"; then
              notify-send "Battery" "Forcing charge to 100%" -i battery-charging
            else
              notify-send "Battery Error" "Failed to force charge: $result" -i dialog-error
            fi
            ;;
          "󰂄 Restore Defaults")
            result=$(dbus-send --system --print-reply --dest=org.nixos.BatteryManager /org/nixos/BatteryManager org.nixos.BatteryManager.RestoreDefaults 2>&1)
            if echo "$result" | grep -q "boolean true"; then
              notify-send "Battery" "Restored to default thresholds" -i battery
            else
              notify-send "Battery Error" "Failed to restore defaults: $result" -i dialog-error
            fi
            ;;
          "󰒓 Custom Settings")
            start=$(echo "" | rofi -dmenu -i -p "Start threshold (%):" \
              -theme-str 'window { location: northeast; anchor: northeast; x-offset: -10px; y-offset: 10px; width: 400px; }')
            if [ -n "$start" ] && echo "$start" | grep -q '^[0-9]\+$'; then
              end=$(echo "" | rofi -dmenu -i -p "End threshold (%):" \
                -theme-str 'window { location: northeast; anchor: northeast; x-offset: -10px; y-offset: 10px; width: 400px; }')
              if [ -n "$end" ] && echo "$end" | grep -q '^[0-9]\+$'; then
                result=$(dbus-send --system --print-reply --dest=org.nixos.BatteryManager /org/nixos/BatteryManager org.nixos.BatteryManager.SetThresholds int32:$start int32:$end 2>&1)
                if echo "$result" | grep -q "boolean true"; then
                  notify-send "Battery" "Custom thresholds set: $start%-$end%" -i battery-good
                else
                  notify-send "Battery Error" "Failed to set custom thresholds: $result" -i dialog-error
                fi
              else
                notify-send "Battery Error" "Invalid end threshold. Please enter a number." -i dialog-error
              fi
            else
              notify-send "Battery Error" "Invalid start threshold. Please enter a number." -i dialog-error
            fi
            ;;
        esac
        ;;
    esac
  '';
}

