{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.usb-reset;
in {
  config = mkIf cfg.enable {
    # USB reset utility scripts
    environment.systemPackages = with pkgs; [
      # Quick USB bus reset script
      (writeShellScriptBin "usb-reset" ''
        #!/usr/bin/env bash
        echo "Resetting USB buses..."

        # Method 1: Reset xHCI controllers via PCI
        echo "Resetting xHCI controllers..."
        for pci_id in $(lspci | grep -i "usb.*xhci" | cut -d' ' -f1); do
          echo "Resetting PCI device $pci_id"
          echo 1 | sudo tee /sys/bus/pci/devices/0000:$pci_id/reset >/dev/null 2>&1 || true
        done

        # Method 2: Unbind and rebind USB controllers
        echo "Unbinding and rebinding USB controllers..."
        for controller in /sys/bus/pci/drivers/xhci_hcd/0000:*; do
          if [ -e "$controller" ]; then
            device=$(basename "$controller")
            echo "Resetting controller $device"
            echo "$device" | sudo tee /sys/bus/pci/drivers/xhci_hcd/unbind >/dev/null 2>&1 || true
            sleep 1
            echo "$device" | sudo tee /sys/bus/pci/drivers/xhci_hcd/bind >/dev/null 2>&1 || true
          fi
        done

        # Method 3: Reset specific problematic USB hubs
        echo "Resetting USB hubs..."
        for hub in /sys/bus/usb/devices/*/authorized; do
          if [ -e "$hub" ]; then
            echo 0 | sudo tee "$hub" >/dev/null 2>&1 || true
            sleep 0.5
            echo 1 | sudo tee "$hub" >/dev/null 2>&1 || true
          fi
        done

        echo "USB reset complete. Wait a few seconds for devices to reconnect."
      '')

      # Targeted reset for specific USB port (3-8 that's failing)
      (writeShellScriptBin "usb-reset-port" ''
        #!/usr/bin/env bash
        PORT="$1"
        if [ -z "$PORT" ]; then
          echo "Usage: usb-reset-port <port-path>"
          echo "Example: usb-reset-port 3-8"
          echo "Available ports:"
          find /sys/bus/usb/devices/ -name "3-*" -type d | sort
          exit 1
        fi

        echo "Resetting USB port $PORT..."

        # Reset the specific port
        if [ -e "/sys/bus/usb/devices/$PORT/authorized" ]; then
          echo 0 | sudo tee "/sys/bus/usb/devices/$PORT/authorized" >/dev/null
          sleep 1
          echo 1 | sudo tee "/sys/bus/usb/devices/$PORT/authorized" >/dev/null
          echo "Port $PORT reset complete."
        else
          echo "Port $PORT not found or not accessible."
        fi
      '')

      # Monitoring script to auto-reset on USB errors
      (writeShellScriptBin "usb-monitor" ''
        #!/usr/bin/env bash
        echo "Starting USB error monitor..."
        echo "Will automatically reset USB on detection of errors."
        echo "Press Ctrl+C to stop."

        journalctl -f -k | while read -r line; do
          if echo "$line" | grep -qi "usb.*error\|usb.*disconnect\|cannot enable.*usb"; then
            echo "USB error detected: $line"
            echo "Triggering USB reset..."
            usb-reset-port 3-8 >/dev/null 2>&1 || true
            sleep 5  # Cooldown to prevent spam
          fi
        done
      '')
    ];

    # Systemd service for automatic USB monitoring (optional)
    systemd.services.usb-monitor = {
      description = "USB Error Monitor and Auto-Reset";
      wantedBy = [ "multi-user.target" ];
      after = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.systemd}/bin/journalctl -f -k";
        ExecStartPost = "${pkgs.bash}/bin/bash -c 'sleep 2 && ${pkgs.systemd}/bin/journalctl -f -k | while read line; do if echo \"$line\" | ${pkgs.gnugrep}/bin/grep -qi \"usb.*error\\|usb.*disconnect\\|cannot enable.*usb\"; then ${pkgs.coreutils}/bin/echo \"USB error detected, resetting port 3-8...\"; if [ -e \"/sys/bus/usb/devices/3-8/authorized\" ]; then echo 0 > /sys/bus/usb/devices/3-8/authorized; sleep 1; echo 1 > /sys/bus/usb/devices/3-8/authorized; fi; sleep 5; fi; done'";
        Restart = "always";
        RestartSec = "10";
        User = "root";
      };
      # Disabled by default - enable manually if needed
      enable = mkDefault false;
    };

    # Udev rule to reset USB on device add/remove events
    services.udev.extraRules = ''
      # Reset USB hub on problematic port when device is added/removed
      ACTION=="add|remove", SUBSYSTEM=="usb", KERNELS=="3-8*", RUN+="${pkgs.bash}/bin/bash -c 'sleep 2 && if [ -e /sys/bus/usb/devices/3-8/authorized ]; then echo 0 > /sys/bus/usb/devices/3-8/authorized; sleep 1; echo 1 > /sys/bus/usb/devices/3-8/authorized; fi'"
    '';

    # Add to sudoers for passwordless USB reset operations
    security.sudo.extraRules = [{
      users = [ "emet" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/usb-reset";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/usb-reset-port";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/bin/tee /sys/bus/usb/devices/*/authorized";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/bin/tee /sys/bus/pci/devices/*/reset";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/bin/tee /sys/bus/pci/drivers/xhci_hcd/*";
          options = [ "NOPASSWD" ];
        }
      ];
    }];
  };
}