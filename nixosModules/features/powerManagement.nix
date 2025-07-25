{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.powerManagement;

  # Desktop environment detection
  isGnomeEnabled = config.services.xserver.desktopManager.gnome.enable;
  isKdeEnabled = config.services.xserver.desktopManager.plasma5.enable || config.services.desktopManager.plasma6.enable;
  hasTraditionalDE = isGnomeEnabled || isKdeEnabled;

  # Create a simple CPU detection script that runs at build time
  cpuDetector = pkgs.writeShellScript "detect-cpu" ''
    if ${pkgs.util-linux}/bin/lscpu | grep -q "GenuineIntel"; then
      echo "intel_pstate=active"
    elif ${pkgs.util-linux}/bin/lscpu | grep -q "AuthenticAMD"; then
      echo "amd_pstate=guided"
    else
      echo ""
    fi
  '';
in {
  options.myNixOS.powerManagement = {
    fixSuspendIssues = mkOption {
      type = types.bool;
      default = true;
      description = "Apply fixes for common suspend/resume issues";
    };
  };

  config = {
    powerManagement = {
      enable = true;
      cpuFreqGovernor = "schedutil";
    };

    services = {
      # Use auto-cpufreq for non-traditional DEs (Hyprland, etc.)
      auto-cpufreq.enable = !hasTraditionalDE;

      # Traditional DEs (GNOME/KDE) use power-profiles-daemon
      power-profiles-daemon.enable = mkDefault hasTraditionalDE;
    };

    # CPU-specific setup at boot time
    systemd.services."cpu-power-setup" = {
      description = "Set CPU-specific power management parameters";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Detect CPU type and log the appropriate setting
        if ${pkgs.util-linux}/bin/lscpu | grep -q "GenuineIntel"; then
          echo "Detected Intel CPU - intel_pstate should be active"
        elif ${pkgs.util-linux}/bin/lscpu | grep -q "AuthenticAMD"; then
          echo "Detected AMD CPU - amd_pstate should be guided"
        else
          echo "Unknown CPU type detected"
        fi
      '';
    };

    # Set kernel parameters based on common CPU types
    boot.kernelParams = [
      # Intel P-state (will be ignored on AMD)
      "intel_pstate=active"
      # AMD P-state (will be ignored on Intel)  
      "amd_pstate=guided"
    ] ++ optionals cfg.fixSuspendIssues [
      "usbcore.autosuspend=-1"  # Fix USB suspend issues
    ];

    # USB wakeup service
    systemd.services."usb-wakeup-enable" = {
      description = "Enable USB device wakeup for external keyboard/mouse";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Enable wakeup for all USB devices and hubs
        find /sys/bus/usb/devices/*/power/wakeup -type f 2>/dev/null | while read -r wakeup_file; do
          echo enabled > "$wakeup_file" 2>/dev/null || true
        done

        echo "USB wakeup configuration completed successfully"
      '';
    };

    # Prevent USB autosuspend issues
    boot.extraModprobeConfig = mkIf cfg.fixSuspendIssues ''
      options usbcore autosuspend=-1
    '';
  };
}

