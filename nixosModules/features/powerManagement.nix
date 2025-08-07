{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.powerManagement;

  # Desktop environment detection
  isGnomeEnabled = config.services.desktopManager.gnome.enable;
  isKdeEnabled = config.services.xserver.desktopManager.plasma5.enable || config.services.desktopManager.plasma6.enable;
  hasTraditionalDE = isGnomeEnabled || isKdeEnabled;
in {
  options.myNixOS.powerManagement = {
    fixSuspendIssues = mkOption {
      type = types.bool;
      default = true;
      description = "Apply fixes for common suspend/resume issues";
    };

    cpuType = mkOption {
      type = types.enum [ "intel" "amd" "both" ];
      default = "both";
      description = "CPU type for power management parameters";
    };
  };

  config = mkIf cfg.enable {
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

    # Add ASUS-specific kernel modules for battery management compatibility
    boot.kernelModules = [ "asus-wmi" "asus-nb-wmi" ];

    # PROPERLY MODULAR: Let user choose or include both (kernel ignores wrong ones)
    boot.kernelParams = [
      # Include both by default - kernel ignores the wrong one
    ] ++ optionals (cfg.cpuType == "intel" || cfg.cpuType == "both") [
      "intel_pstate=active"
    ] ++ optionals (cfg.cpuType == "amd" || cfg.cpuType == "both") [
      "amd_pstate=guided"
    ] ++ optionals cfg.fixSuspendIssues [
      "usbcore.autosuspend=-1"
    ];

    # CPU detection service
    systemd.services."cpu-power-setup" = {
      description = "Log CPU-specific power management parameters";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if ${pkgs.util-linux}/bin/lscpu | grep -q "GenuineIntel"; then
          echo "Detected Intel CPU - intel_pstate=active should be active"
        elif ${pkgs.util-linux}/bin/lscpu | grep -q "AuthenticAMD"; then
          echo "Detected AMD CPU - amd_pstate=guided should be active"
        fi
      '';
    };

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

