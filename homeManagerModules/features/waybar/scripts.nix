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

  waybar-volume = pkgs.writeShellScriptBin "waybar-volume" ''
    volume=$(pamixer --get-volume)
    is_muted=$(pamixer --get-mute)
    
    if [ "$is_muted" = "true" ]; then
      echo "󰖁 $volume%"
    else
      echo "󰕾 $volume%"
    fi
  '';
  
  waybar-volume-toggle = pkgs.writeShellScriptBin "waybar-volume-toggle" ''
    # Auto-unmute hardware controls first (prevent ALSA stuck muting)
    amixer -c 2 sset Master unmute >/dev/null 2>&1 || true
    amixer -c 2 sset Speaker unmute >/dev/null 2>&1 || true
    amixer -c 2 sset "Auto-Mute Mode" Disabled >/dev/null 2>&1 || true
  
    # Then toggle the software mute
    pamixer --toggle-mute
  '';
  
  waybar-volume-up = pkgs.writeShellScriptBin "waybar-volume-up" ''
    # Auto-unmute hardware controls first
    amixer -c 2 sset Master unmute >/dev/null 2>&1 || true
    amixer -c 2 sset Speaker unmute >/dev/null 2>&1 || true
    amixer -c 2 sset "Auto-Mute Mode" Disabled >/dev/null 2>&1 || true
  
    # Then increase volume
    pamixer --increase 5
  '';
  
  waybar-volume-down = pkgs.writeShellScriptBin "waybar-volume-down" ''
    # Auto-unmute hardware controls first
    amixer -c 2 sset Master unmute >/dev/null 2>&1 || true
    amixer -c 2 sset Speaker unmute >/dev/null 2>&1 || true
    amixer -c 2 sset "Auto-Mute Mode" Disabled >/dev/null 2>&1 || true
  
    # Then decrease volume
    pamixer --decrease 5
  '';

  waybar-volume-cycle = pkgs.writeShellScriptBin "waybar-volume-cycle" ''
    # Get ONLY the sinks section (stop at next section)
    sinks_only=$(wpctl status | sed -n '/├─ Sinks:/,/├─ Sources:/p' | head -n -1)
  
    # Extract device IDs with correct regex for wpctl format
    built_in=$(echo "$sinks_only" | grep "Family 17h" | grep -o '[0-9]\+' | head -1)
    bluetooth=$(echo "$sinks_only" | grep "Shokz\|OpenRun" | grep -o '[0-9]\+' | head -1)
    hdmi=$(echo "$sinks_only" | grep -i "hdmi\|navi" | grep -o '[0-9]\+' | head -1)
  
    # Get current default (look for the * marker)
    current_default=$(echo "$sinks_only" | grep "\*" | grep -o '[0-9]\+' | head -1)
  
    echo "Debug: built_in='$built_in', bluetooth='$bluetooth', hdmi='$hdmi', current='$current_default'"
  
    # Count available outputs
    available_count=0
    [ -n "$built_in" ] && available_count=$((available_count + 1))
    [ -n "$bluetooth" ] && available_count=$((available_count + 1))
    [ -n "$hdmi" ] && available_count=$((available_count + 1))
  
    if [ $available_count -lt 2 ]; then
      notify-send "Audio Output" "No additional outputs available (found: $available_count)" -i audio-speakers
      exit 0
    fi
  
    # Cycle: Built-in → Bluetooth → HDMI → Built-in
    if [ "$current_default" = "$built_in" ] && [ -n "$bluetooth" ]; then
      wpctl set-default "$bluetooth"
      notify-send "Audio Output" "Switched to Bluetooth headset" -i audio-headphones
    elif [ "$current_default" = "$bluetooth" ] && [ -n "$hdmi" ]; then
      wpctl set-default "$hdmi"
      notify-send "Audio Output" "Switched to HDMI output" -i video-display
    else
      wpctl set-default "$built_in"
      notify-send "Audio Output" "Switched to built-in speakers" -i audio-speakers
    fi
  '';

  # Fixed microphone control - follows system default
  waybar-microphone = pkgs.writeShellScriptBin "waybar-microphone" ''
    # Get volume info for default audio source
    volume_info=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
    percentage=$(echo "$volume_info" | awk '{printf "%.0f", $2 * 100}')
  
    # Check mute state and display with working Nerd Font icons
    if echo "$volume_info" | grep -q "MUTED"; then
      echo "󰍭 $percentage%"  # Microphone muted (this should work)
    else
      echo "󰍬 $percentage%"  # Microphone unmuted (this should work)
    fi
  '';

  waybar-microphone-toggle = pkgs.writeShellScriptBin "waybar-microphone-toggle" ''
    # Auto-unmute hardware controls first (prevent ALSA stuck muting)
    amixer -c 2 sset Capture unmute >/dev/null 2>&1 || true
    amixer -c 2 sset "Internal Mic" unmute >/dev/null 2>&1 || true
    amixer -c 2 sset "Headset Mic" unmute >/dev/null 2>&1 || true
  
    # Then toggle the PipeWire software mute
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
  '';

  waybar-microphone-volume-up = pkgs.writeShellScriptBin "waybar-microphone-volume-up" ''
    # Adjust system default source
    wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+
  '';
  
  waybar-microphone-volume-down = pkgs.writeShellScriptBin "waybar-microphone-volume-down" ''
    # Adjust system default source
    wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
  '';

  waybar-microphone-cycle = pkgs.writeShellScriptBin "waybar-microphone-cycle" ''
    # Get current default source by name, then find its ID
    current_name=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ | grep 'node.name' | sed 's/.*node.name = "\([^"]*\)".*/\1/')
    current_source=$(wpctl status | grep "$current_name" | grep -o '[0-9]\+' | head -1)
  
    # Find built-in microphone (Family 17h Analog Stereo - in Sources section only)
    built_in_mic=$(wpctl status | sed -n '/Sources:/,/Filters:/p' | grep "Family 17h.*Analog Stereo" | grep -o '[0-9]\+' | head -1)
  
    # Find Bluetooth microphone (bluez_input)
    bluetooth_mic=$(wpctl status | grep "bluez_input\." | grep -o '[0-9]\+' | head -1)
  
    echo "Debug: built_in_mic='$built_in_mic', bluetooth_mic='$bluetooth_mic', current='$current_source' (name: $current_name)"
  
    # Cycle logic: built-in -> bluetooth -> built-in
    if [ "$current_source" = "$built_in_mic" ] && [ -n "$bluetooth_mic" ]; then
      echo "Switching to Bluetooth microphone"
      wpctl set-default "$bluetooth_mic"
    elif [ "$current_source" = "$bluetooth_mic" ] && [ -n "$built_in_mic" ]; then
      echo "Switching to built-in microphone"
      wpctl set-default "$built_in_mic"
    elif [ -n "$built_in_mic" ]; then
      echo "Defaulting to built-in microphone"
      wpctl set-default "$built_in_mic"
    else
      echo "No microphones found"
    fi
  '';
}
