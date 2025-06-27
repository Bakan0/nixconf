{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.batteryManagement;
in {
  config = mkIf cfg.enable {
    # Systemd service to set battery charging thresholds
    systemd.services.battery-charge-thresholds = {
      description = "Set battery charging thresholds";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "set-battery-thresholds" ''
          #!/bin/sh

          # Find all battery power supplies
          for battery in /sys/class/power_supply/BAT*; do
            if [ -d "$battery" ]; then
              battery_name=$(basename "$battery")

              # Check if charging threshold controls exist
              if [ -w "$battery/charge_control_start_threshold" ] && [ -w "$battery/charge_control_end_threshold" ]; then
                echo "Setting charging thresholds for $battery_name"
                echo "${toString cfg.startThreshold}" > "$battery/charge_control_start_threshold"
                echo "${toString cfg.endThreshold}" > "$battery/charge_control_end_threshold"
                echo "Set $battery_name: start=${toString cfg.startThreshold}%, end=${toString cfg.endThreshold}%"
              else
                echo "Charging threshold controls not available for $battery_name"
              fi
            fi
          done
        '';
      };
    };

    # Modern udev rule format
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "battery-thresholds-udev-rules";
        destination = "/etc/udev/rules.d/99-battery-thresholds.rules";
        text = ''
          # Set battery charging thresholds when battery is detected
          SUBSYSTEM=="power_supply", KERNEL=="BAT*", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}="battery-charge-thresholds.service"
        '';
      })
    ];

    # Management script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "battery-thresholds" ''
        #!/bin/sh
        case "$1" in
          status)
            for battery in /sys/class/power_supply/BAT*; do
              if [ -d "$battery" ]; then
                name=$(basename "$battery")
                if [ -r "$battery/charge_control_start_threshold" ] && [ -r "$battery/charge_control_end_threshold" ]; then
                  start=$(cat "$battery/charge_control_start_threshold" 2>/dev/null || echo "N/A")
                  end=$(cat "$battery/charge_control_end_threshold" 2>/dev/null || echo "N/A")
                  echo "$name: start=$start%, end=$end%"
                else
                  echo "$name: threshold controls not available"
                fi
              fi
            done
            ;;
          set)
            if [ -z "$2" ] || [ -z "$3" ]; then
              echo "Usage: battery-thresholds set <start> <end>"
              exit 1
            fi
            sudo systemctl stop battery-charge-thresholds.service
            for battery in /sys/class/power_supply/BAT*; do
              if [ -d "$battery" ] && [ -w "$battery/charge_control_start_threshold" ] && [ -w "$battery/charge_control_end_threshold" ]; then
                echo "$2" | sudo tee "$battery/charge_control_start_threshold" > /dev/null
                echo "$3" | sudo tee "$battery/charge_control_end_threshold" > /dev/null
                echo "Set $(basename "$battery"): start=$2%, end=$3%"
              fi
            done
            ;;
          *)
            echo "Usage: battery-thresholds {status|set <start> <end>}"
            echo "Examples:"
            echo "  battery-thresholds status"
            echo "  battery-thresholds set 55 70"
            ;;
        esac
      '')
    ];
  };

  options.myNixOS.batteryManagement = {
    startThreshold = mkOption {
      type = types.int;
      default = 55;  # Updated to your preferred value
      description = "Battery charging start threshold percentage";
    };

    endThreshold = mkOption {
      type = types.int;
      default = 70;  # Updated to your preferred value
      description = "Battery charging end threshold percentage";
    };
  };
}

