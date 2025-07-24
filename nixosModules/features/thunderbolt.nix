{ config, lib, pkgs, ... }:
let cfg = config.myNixOS.thunderbolt;
in {
  config = lib.mkIf cfg.enable {
    # Enable Thunderbolt support
    services.hardware.bolt.enable = true;

    # Alternative kernel parameters (since security=none is ignored)
    boot.kernelParams = [ 
      "thunderbolt.dyndbg=+p"    # Enable debugging
      "pci=assign-busses"        # Force PCI assignment
    ];

    # Ensure modules load early
    boot.kernelModules = [ "thunderbolt" "usb4" ];

    # Create udev rule to auto-authorize DisplayPort tunneling
    services.udev.extraRules = ''
      # Auto-authorize Thunderbolt devices for DisplayPort
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"

      # Enable DisplayPort tunneling for Razer Core X
      ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{vendor}=="0x127", ATTR{device}=="0x3", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > /sys/bus/thunderbolt/devices/%k/authorized'"
    '';

    # Systemd service to enable DP tunneling on boot
    systemd.services.thunderbolt-dp-enable = {
      description = "Enable Thunderbolt DisplayPort tunneling";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        # Wait for Thunderbolt devices
        sleep 5

        # Enable DP tunneling if available
        for device in /sys/bus/thunderbolt/devices/0-*; do
          if [ -f "$device/authorized" ]; then
            echo 1 > "$device/authorized" 2>/dev/null || true
          fi
        done
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}

