{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.sysadmin;
in {
  options.myNixOS.sysadmin = {
    allowedActions = mkOption {
      type = types.enum [ "password" "ask" "anarchy" ];
      default = "password";
      description = ''Control sudo behavior for curated administrative operations:
        - password: Require full password (default, safest)
        - ask: Simple Y/N confirmation prompt (convenient for manual use)
        - anarchy: No prompts for rebuilds/restarts/reboots (enables automation)'';
    };
  };

  config = mkIf cfg.enable {
    # Safe diagnostic commands (always enabled)
    security.sudo.extraRules = [
      # System diagnostics (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/dmidecode"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/dmesg"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lsblk"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lscpu"; options = ["NOPASSWD"]; }]; }
      
      # Hardware information (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lspci"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lsusb"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lsmod"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lshw"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/hwinfo"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/fdisk -l"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/blkid"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/mount"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/df"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/free"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ps"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/netstat"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ss"; options = ["NOPASSWD"]; }]; }
      
      # Network diagnostics (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ip addr show"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ip route show"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ip link show"; options = ["NOPASSWD"]; }]; }
      
      # Service management (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl status *"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl show *"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl list-*"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl is-*"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl cat *"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/journalctl"; options = ["NOPASSWD"]; }]; }

      # File operations (harmless read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/du"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/find"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ls"; options = ["NOPASSWD"]; }]; }

      # Libvirt management (for xfer-libvirt script)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/virsh *"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/mkdir"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/rsync"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/*/bin/rsync"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl restart libvirtd"; options = ["NOPASSWD"]; }]; }
    ] ++ optionals (cfg.allowedActions == "anarchy") [
      # Anarchy mode: curated administrative commands with no prompts
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/switch-to-configuration"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/nixos-rebuild"; options = ["NOPASSWD"]; }]; }
      # systemctl covers reboot/halt/poweroff/shutdown (they're all symlinks to systemctl)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl"; options = ["NOPASSWD"]; }]; }
      # Garbage collection commands (called by nh clean)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/nix-collect-garbage"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/nix store --gc"; options = ["NOPASSWD"]; }]; }
    ];

    # Ask mode: Y/N confirmation for dangerous commands
    security.sudo.extraConfig = optionalString (cfg.allowedActions == "ask") ''
      Defaults!DANGEROUS_CMDS passprompt="[sudo] Type 'Y' to confirm: "
      Defaults!DANGEROUS_CMDS passwd_tries=1
      Cmnd_Alias DANGEROUS_CMDS = /run/current-system/sw/bin/switch-to-configuration, /run/current-system/sw/bin/nixos-rebuild, /run/current-system/sw/bin/systemctl, /run/current-system/sw/bin/reboot
      %wheel ALL=(ALL) DANGEROUS_CMDS
    '';

    # Ensure required packages are available system-wide
    environment.systemPackages = with pkgs; [
      systemd      # bootctl, systemctl, journalctl
      util-linux   # dmesg, lsblk, fdisk, lscpu
      dmidecode    # dmidecode
      pciutils     # lspci  
      usbutils     # lsusb
      iproute2     # ip
    ];
  };
}
