{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS."hardware-power";
  hasZfs = config.boot.zfs.enabled or false;
in {
  options.myNixOS."hardware-power" = {
    powerButton = {
      action = mkOption {
        type = types.enum [ "poweroff" "suspend" "hibernate" "ignore" ];
        default = "poweroff";
        description = "Action to take when power button is pressed";
      };
    };

    lidSwitch = {
      action = mkOption {
        type = types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
        default = "suspend";
        description = "Action to take when laptop lid is closed";
      };

      actionOnAC = mkOption {
        type = types.enum [ "suspend" "hibernate" "poweroff" "ignore" ];
        default = "ignore";
        description = "Action when lid is closed while on AC power";
      };
    };

    ensureCleanShutdown = mkOption {
      type = types.bool;
      default = true;
      description = "Ensure filesystems are cleanly unmounted on shutdown";
    };
  };

  config = mkMerge [
    {
      # Configure systemd-logind for power button and lid behavior
      services.logind.settings.Login = {
        HandlePowerKey = cfg.powerButton.action;
        HandlePowerKeyLongPress = cfg.powerButton.action;
        PowerKeyIgnoreInhibited = "no";

        HandleLidSwitch = cfg.lidSwitch.action;
        HandleLidSwitchExternalPower = cfg.lidSwitch.actionOnAC;
        HandleLidSwitchDocked = "ignore";
        LidSwitchIgnoreInhibited = "no";
      };
    }

    (mkIf cfg.ensureCleanShutdown {
      # Only add ZFS export service if clean shutdown is enabled
      systemd.services."ensure-clean-shutdown" = {
        description = "Ensure clean filesystem shutdown";
        wantedBy = [ "shutdown.target" ];
        before = [ "shutdown.target" "umount.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = pkgs.writeShellScript "clean-shutdown" ''
            # Sync all filesystems first
            ${pkgs.coreutils}/bin/sync

            # Export ZFS pools if ZFS is in use
            ${optionalString hasZfs ''
              if ${pkgs.zfs}/bin/zpool list >/dev/null 2>&1; then
                echo "Exporting ZFS pools..."
                ${pkgs.zfs}/bin/zpool export -a || true
              fi
            ''}

            # Give processes time to finish
            sleep 1
          '';
        };
      };
    })
  ];
}