{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.batteryManagement;

  # Hardware detection
  batteryHardwareDetector = pkgs.writeShellScript "detect-battery-hardware" ''
    if [ -f "/sys/devices/platform/asus-nb-wmi/charge_mode" ]; then
      echo "asus"
    elif [ -f "/sys/class/power_supply/BAT0/charge_control_start_threshold" ] && [ -f "/sys/class/power_supply/BAT0/charge_control_end_threshold" ]; then
      echo "standard"
    elif [ -d "/sys/class/power_supply/BAT0" ]; then
      echo "basic"
    else
      echo "none"
    fi
  '';

in {
  options.myNixOS.batteryManagement = {
    startThreshold = mkOption {
      type = types.int;
      default = 40;
      description = "Battery charging start threshold percentage";
    };

    endThreshold = mkOption {
      type = types.int;
      default = 60;
      description = "Battery charging end threshold percentage";
    };
  };

  config = mkIf cfg.enable {
    # Single PolicyKit rule for one service
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "battery-control.service" &&
            subject.user == "${config.myNixOS.username or "emet"}") {
          return polkit.Result.YES;
        }
      });
    '';

    # Single unified service for all battery operations
    systemd.services.battery-control = {
      description = "Battery Control Service";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "battery-control" ''
          HARDWARE_TYPE=$(${batteryHardwareDetector})

          # Default operation: set configured defaults
          OPERATION="defaults"
          START_THRESH=${toString cfg.startThreshold}
          END_THRESH=${toString cfg.endThreshold}

          # Check for operation arguments
          if [ -f "/tmp/battery-operation" ]; then
            source /tmp/battery-operation
            rm -f /tmp/battery-operation
          fi

          safe_write() {
            local file="$1"
            local value="$2"
            local desc="$3"
            if echo "$value" > "$file" 2>/dev/null; then
              echo "✓ $desc"
              return 0
            else
              echo "✗ Failed: $desc"
              return 1
            fi
          }

          echo "Battery control: $OPERATION (hardware: $HARDWARE_TYPE)"

          case "$HARDWARE_TYPE" in
            asus)
              for battery in /sys/class/power_supply/BAT*; do
                if [ -d "$battery" ]; then
                  name=$(basename "$battery")
                  safe_write "$battery/charge_control_end_threshold" "$END_THRESH" "$name end=$END_THRESH%"

                  # Try charge mode (graceful failure)
                  if [ "$END_THRESH" -le 60 ]; then
                    safe_write "/sys/devices/platform/asus-nb-wmi/charge_mode" "2" "Max Lifespan mode" || true
                  elif [ "$END_THRESH" -le 80 ]; then
                    safe_write "/sys/devices/platform/asus-nb-wmi/charge_mode" "1" "Balanced mode" || true
                  else
                    safe_write "/sys/devices/platform/asus-nb-wmi/charge_mode" "0" "Normal mode" || true
                  fi
                fi
              done
              ;;
            standard)
              for battery in /sys/class/power_supply/BAT*; do
                if [ -d "$battery" ]; then
                  name=$(basename "$battery")
                  safe_write "$battery/charge_control_start_threshold" "$START_THRESH" "$name start=$START_THRESH%"
                  safe_write "$battery/charge_control_end_threshold" "$END_THRESH" "$name end=$END_THRESH%"
                fi
              done
              ;;
            *)
              echo "No supported battery hardware detected"
              ;;
          esac
        '';
      };
    };

    # Auto-start service at boot to set defaults
    systemd.services.battery-control-init = {
      description = "Initialize Battery Thresholds";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/systemctl start battery-control.service";
      };
    };

    # Clean, unified CLI tool
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "battery-thresholds" ''
        HARDWARE_TYPE=$(${batteryHardwareDetector})

        get_battery_info() {
          local battery="$1"
          local level=$(cat "$battery/capacity" 2>/dev/null || echo "unknown")
          local status=$(cat "$battery/status" 2>/dev/null || echo "unknown")
          echo "$level% ($status)"
        }

        call_service() {
          local operation="$1"
          local start="$2"
          local end="$3"

          # Write operation parameters
          {
            echo "OPERATION=\"$operation\""
            [ -n "$start" ] && echo "START_THRESH=$start"
            [ -n "$end" ] && echo "END_THRESH=$end"
          } > /tmp/battery-operation

          # Call the service
          systemctl start battery-control.service

          # Check result
          sleep 1
          if systemctl is-failed battery-control.service >/dev/null; then
            echo "✗ Operation failed"
            return 1
          else
            echo "✓ Operation completed"
            return 0
          fi
        }

        case "$1" in
          status)
            for battery in /sys/class/power_supply/BAT*; do
              if [ -d "$battery" ]; then
                name=$(basename "$battery")
                info=$(get_battery_info "$battery")

                case "$HARDWARE_TYPE" in
                  asus)
                    end=$(cat "$battery/charge_control_end_threshold" 2>/dev/null || echo "N/A")
                    charge_mode=$(cat "/sys/devices/platform/asus-nb-wmi/charge_mode" 2>/dev/null || echo "N/A")
                    case "$charge_mode" in
                      0) mode_desc="Normal" ;;
                      1) mode_desc="Balanced (80%)" ;;
                      2) mode_desc="Max Lifespan (60%)" ;;
                      *) mode_desc="Unknown" ;;
                    esac
                    echo "$name: $info - ASUS: end=$end%, mode=$mode_desc"
                    ;;
                  standard)
                    start=$(cat "$battery/charge_control_start_threshold" 2>/dev/null || echo "N/A")
                    end=$(cat "$battery/charge_control_end_threshold" 2>/dev/null || echo "N/A")
                    echo "$name: $info - thresholds: start=$start%, end=$end%"
                    ;;
                  *)
                    echo "$name: $info - no threshold control"
                    ;;
                esac
              fi
            done
            ;;
          set)
            [ -z "$2" ] || [ -z "$3" ] && { echo "Usage: battery-thresholds set <start> <end>"; exit 1; }
            echo "Setting battery thresholds: start=$2%, end=$3%"
            call_service "set" "$2" "$3"
            ;;
          force-charge)
            echo "Forcing charge to 100%..."
            call_service "force-charge" "0" "100"
            ;;
          restore)
            echo "Restoring defaults..."
            call_service "defaults"
            ;;
          *)
            echo "Usage: battery-thresholds {status|set|force-charge|restore}"
            echo "Detected hardware: $HARDWARE_TYPE"
            ;;
        esac
      '')
    ];
  };
}

