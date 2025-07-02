{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.batteryManagement;

  # D-Bus service for battery management
  batteryDbusService = pkgs.writeTextFile {
    name = "battery-manager-dbus-service";
    destination = "/share/dbus-1/system-services/org.nixos.BatteryManager.service";
    text = ''
      [D-BUS Service]
      Name=org.nixos.BatteryManager
      Exec=${pkgs.python3.withPackages (ps: with ps; [ dbus-python pygobject3 ])}/bin/python3 ${batteryDbusScript}
      User=root
      SystemdService=battery-manager-dbus.service
    '';
  };

  batteryDbusScript = pkgs.writeScript "battery-manager-dbus.py" ''
    #!/usr/bin/env python3
    # Force rebuild: 2025-07-02-14:50
    import dbus
    import dbus.service
    import dbus.mainloop.glib
    from gi.repository import GLib
    import glob
    import os
    import threading
    import subprocess
    import sys
  
    class BatteryManager(dbus.service.Object):
        def __init__(self):
            bus_name = dbus.service.BusName('org.nixos.BatteryManager', bus=dbus.SystemBus())
            dbus.service.Object.__init__(self, bus_name, '/org/nixos/BatteryManager')
            self.temp_timer = None
  
        @dbus.service.method("org.nixos.BatteryManager", in_signature="", out_signature="a{sa{sv}}")
        def GetStatus(self):
            """Get current battery status and thresholds"""
            result = {}
            for battery_path in glob.glob('/sys/class/power_supply/BAT*'):
                if os.path.isdir(battery_path):
                    name = os.path.basename(battery_path)
                    try:
                        capacity = int(open(battery_path + '/capacity').read().strip())
                        status = open(battery_path + '/status').read().strip()
                        start_thresh = int(open(battery_path + '/charge_control_start_threshold').read().strip())
                        end_thresh = int(open(battery_path + '/charge_control_end_threshold').read().strip())
  
                        result[name] = {
                            'capacity': dbus.Int32(capacity),
                            'status': dbus.String(status),
                            'start_threshold': dbus.Int32(start_thresh),
                            'end_threshold': dbus.Int32(end_thresh)
                        }
                    except (IOError, ValueError) as e:
                        result[name] = {'error': dbus.String(f'Could not read battery info: {e}')}
            return result
  
        @dbus.service.method("org.nixos.BatteryManager", in_signature="ii", out_signature="b")
        def SetThresholds(self, start, end):
            """Set permanent battery thresholds"""
            try:
                print(f"DEBUG: Setting thresholds {start}-{end}", file=sys.stderr)
  
                # Try direct file writing first (like the CLI tool does)
                for battery in glob.glob('/sys/class/power_supply/BAT*'):
                    if os.path.isdir(battery):
                        start_file = battery + '/charge_control_start_threshold'
                        end_file = battery + '/charge_control_end_threshold'
  
                        if os.path.exists(start_file) and os.path.exists(end_file):
                            print(f"DEBUG: Writing to {start_file} and {end_file}", file=sys.stderr)
                            with open(start_file, 'w') as f:
                                f.write(str(start))
                            with open(end_file, 'w') as f:
                                f.write(str(end))
                            print(f"DEBUG: Successfully set thresholds for {battery}", file=sys.stderr)
                            return True
  
                print("DEBUG: No battery threshold files found", file=sys.stderr)
                return False
  
            except Exception as e:
                print(f"DEBUG: Error setting thresholds: {e}", file=sys.stderr)
                return False
  
        @dbus.service.method("org.nixos.BatteryManager", in_signature="", out_signature="b")
        def ForceCharge(self):
            """Force immediate charging to 100%"""
            try:
                print("DEBUG: Force charging", file=sys.stderr)
                return self.SetThresholds(0, 100)
            except Exception as e:
                print(f"DEBUG: Error forcing charge: {e}", file=sys.stderr)
                return False
  
        @dbus.service.method("org.nixos.BatteryManager", in_signature="", out_signature="b")
        def RestoreDefaults(self):
            """Restore default thresholds"""
            try:
                print("DEBUG: Restoring defaults", file=sys.stderr)
                return self.SetThresholds(40, 60)
            except Exception as e:
                print(f"DEBUG: Error restoring defaults: {e}", file=sys.stderr)
                return False
  
    if __name__ == '__main__':
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        battery_manager = BatteryManager()
        loop = GLib.MainLoop()
        loop.run()
  '';


in {
  config = mkIf cfg.enable {
    # Original systemd service for initial setup
    systemd.services.battery-charge-thresholds = {
      description = "Set battery charging thresholds";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "set-battery-thresholds" ''
          for battery in /sys/class/power_supply/BAT*; do
            if [ -d "$battery" ]; then
              battery_name=$(basename "$battery")
              if [ -f "$battery/charge_control_start_threshold" ] && [ -f "$battery/charge_control_end_threshold" ]; then
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

    # D-Bus service for user interaction
    systemd.services.battery-manager-dbus = {
      description = "Battery Manager D-Bus Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "dbus.service" ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.nixos.BatteryManager";
        ExecStart = "${pkgs.python3.withPackages (ps: with ps; [ dbus-python pygobject3 ])}/bin/python3 ${batteryDbusScript}";
        User = "root";
        Restart = "on-failure";
      };
      environment = {
        GI_TYPELIB_PATH = "${pkgs.glib.out}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0";
      };
    };

    # D-Bus configuration
    services.dbus.packages = [ 
      batteryDbusService
      (pkgs.writeTextFile {
        name = "battery-manager-dbus-policy";
        destination = "/share/dbus-1/system.d/org.nixos.BatteryManager.conf";
        text = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE busconfig PUBLIC
            "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
            "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
          <busconfig>
            <policy user="root">
              <allow own="org.nixos.BatteryManager"/>
              <allow send_destination="org.nixos.BatteryManager"/>
            </policy>
            <policy context="default">
              <allow send_destination="org.nixos.BatteryManager"/>
            </policy>
          </busconfig>
        '';
      })
    ];

    # udev rules
    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "battery-thresholds-udev-rules";
        destination = "/etc/udev/rules.d/99-battery-thresholds.rules";
        text = ''
          SUBSYSTEM=="power_supply", KERNEL=="BAT*", ACTION=="add", TAG+="systemd", ENV{SYSTEMD_WANTS}="battery-charge-thresholds.service"
        '';
      })
    ];

    # CLI tool only
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "battery-thresholds" ''
        get_battery_level() {
          local battery="$1"
          if [ -r "$battery/capacity" ]; then
            cat "$battery/capacity"
          else
            echo "unknown"
          fi
        }

        get_charging_status() {
          local battery="$1"
          if [ -r "$battery/status" ]; then
            cat "$battery/status"
          else
            echo "unknown"
          fi
        }

        case "$1" in
          status)
            for battery in /sys/class/power_supply/BAT*; do
              if [ -d "$battery" ]; then
                name=$(basename "$battery")
                level=$(get_battery_level "$battery")
                status=$(get_charging_status "$battery")
                if [ -r "$battery/charge_control_start_threshold" ] && [ -r "$battery/charge_control_end_threshold" ]; then
                  start=$(cat "$battery/charge_control_start_threshold" 2>/dev/null || echo "N/A")
                  end=$(cat "$battery/charge_control_end_threshold" 2>/dev/null || echo "N/A")
                  echo "$name: $level% ($status) - thresholds: start=$start%, end=$end%"
                else
                  echo "$name: $level% ($status) - threshold controls not available"
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
            start_threshold="$2"
            end_threshold="$3"
            for battery in /sys/class/power_supply/BAT*; do
              if [ -d "$battery" ] && [ -f "$battery/charge_control_start_threshold" ] && [ -f "$battery/charge_control_end_threshold" ]; then
                echo "$2" | sudo tee "$battery/charge_control_start_threshold" > /dev/null
                echo "$3" | sudo tee "$battery/charge_control_end_threshold" > /dev/null
                echo "Set $(basename "$battery"): start=$2%, end=$3%"
              fi
            done
            ;;
          force-charge)
            echo "Forcing immediate charge by temporarily setting thresholds to 0%/100%..."
            for battery in /sys/class/power_supply/BAT*; do
              if [ -d "$battery" ] && [ -f "$battery/charge_control_start_threshold" ] && [ -f "$battery/charge_control_end_threshold" ]; then
                current_level=$(get_battery_level "$battery")
                force_start=0

                echo "$force_start" | sudo tee "$battery/charge_control_start_threshold" > /dev/null
                echo "100" | sudo tee "$battery/charge_control_end_threshold" > /dev/null
                echo "Forced charging for $(basename "$battery") (current: $current_level%)"
              fi
            done
            echo "Charging should start immediately. Use 'battery-thresholds restore' to return to normal."
            ;;
          restore)
            echo "Restoring default battery thresholds..."
            sudo systemctl restart battery-charge-thresholds.service
            echo "Restored to defaults: start=${toString cfg.startThreshold}%, end=${toString cfg.endThreshold}%"
            ;;
          *)
            echo "Usage: battery-thresholds {status|set|force-charge|restore}"
            echo ""
            echo "Commands:"
            echo "  status                    - Show current battery status and thresholds"
            echo "  set <start> <end>         - Set permanent thresholds"
            echo "  force-charge              - Force immediate charging to 100%"
            echo "  restore                   - Restore default thresholds"
            ;;
        esac
      '')
    ];
  };

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
}

