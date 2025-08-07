{ pkgs }:

{
  waybar-battery = pkgs.writeShellScriptBin "waybar-battery" ''
    get_battery_info() {
      battery-thresholds status 2>/dev/null
    }

    case "$1" in
      status)
        info=$(get_battery_info)
        if echo "$info" | grep -q "BAT0:"; then
          capacity=$(echo "$info" | sed 's/.*BAT0: \([0-9]*\)%.*/\1/')
          status=$(echo "$info" | sed 's/.*(\([^)]*\)).*/\1/' | tr -d '\n\r')

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

  # Keep your working volume scripts exactly as they are
  waybar-volume = pkgs.writeShellScriptBin "waybar-volume" ''
    if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
      vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
      echo "$vol% 󰖁"
    else
      vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}')
      if [ "$vol" -gt 66 ]; then
        icon="󰕾"
      elif [ "$vol" -gt 33 ]; then
        icon="󰖀"
      else
        icon="󰕿"
      fi
      echo "$vol% $icon"
    fi
  '';

  waybar-volume-toggle = pkgs.writeShellScriptBin "waybar-volume-toggle" ''
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
  '';

  waybar-volume-up = pkgs.writeShellScriptBin "waybar-volume-up" ''
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
  '';

  waybar-volume-down = pkgs.writeShellScriptBin "waybar-volume-down" ''
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
  '';

  # Fixed microphone control - manages both hardware and filtered sources
  waybar-microphone = pkgs.writeShellScriptBin "waybar-microphone" ''
    # Get hardware source ID dynamically
    hw_source=$(wpctl status | grep "Family 17h" | grep "Sources:" -A 10 | grep "\*" | sed 's/.*\([0-9]\+\)\..*/\1/')
  
    # Check if rnnoise source exists
    if wpctl status | grep -q "rnnoise_source"; then
      # Show filtered source status but check hardware mute state
      if wpctl get-volume "$hw_source" 2>/dev/null | grep -q MUTED; then
        vol=$(wpctl get-volume 39 2>/dev/null | awk '{print int($2*100)}' || echo "0")
        echo "$vol% 󰍭"
      else
        vol=$(wpctl get-volume 39 2>/dev/null | awk '{print int($2*100)}' || echo "0")
        echo "$vol% 󰍬"
      fi
    else
      # Fallback to hardware source only
      if wpctl get-volume "$hw_source" 2>/dev/null | grep -q MUTED; then
        vol=$(wpctl get-volume "$hw_source" 2>/dev/null | awk '{print int($2*100)}' || echo "0")
        echo "$vol% 󰍭"
      else
        vol=$(wpctl get-volume "$hw_source" 2>/dev/null | awk '{print int($2*100)}' || echo "0")
        echo "$vol% 󰍬"
      fi
    fi
  '';
  
  waybar-microphone-toggle = pkgs.writeShellScriptBin "waybar-microphone-toggle" ''
    # Get hardware source ID dynamically
    hw_source=$(wpctl status | grep "Family 17h" | grep "Sources:" -A 10 | grep "\*" | sed 's/.*\([0-9]\+\)\..*/\1/')
  
    # Toggle both hardware and filtered sources
    wpctl set-mute "$hw_source" toggle
    if wpctl status | grep -q "rnnoise_source"; then
      wpctl set-mute 39 toggle
    fi
  '';
  
  waybar-microphone-volume-up = pkgs.writeShellScriptBin "waybar-microphone-volume-up" ''
    # Get hardware source ID dynamically
    hw_source=$(wpctl status | grep "Family 17h" | grep "Sources:" -A 10 | grep "\*" | sed 's/.*\([0-9]\+\)\..*/\1/')
  
    # Adjust both hardware and filtered sources
    wpctl set-volume "$hw_source" 5%+
    if wpctl status | grep -q "rnnoise_source"; then
      wpctl set-volume 39 5%+
    fi
  '';
  
  waybar-microphone-volume-down = pkgs.writeShellScriptBin "waybar-microphone-volume-down" ''
    # Get hardware source ID dynamically  
    hw_source=$(wpctl status | grep "Family 17h" | grep "Sources:" -A 10 | grep "\*" | sed 's/.*\([0-9]\+\)\..*/\1/')
  
    # Adjust both hardware and filtered sources
    wpctl set-volume "$hw_source" 5%-
    if wpctl status | grep -q "rnnoise_source"; then
      wpctl set-volume 39 5%-
    fi
  '';
}
