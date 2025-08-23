{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.sysadmin-claude;
in {
  config = mkIf cfg.enable {
    # Minimal, correct approach - specific NOPASSWD rules for individual commands
    # Everything else defaults to requiring passwords (secure by default)
    security.sudo.extraRules = [
      # System diagnostics (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/dmidecode"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/dmesg"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lsblk"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lscpu"; options = ["NOPASSWD"]; }]; }
      
      # Hardware information (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lspci"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/lsusb"; options = ["NOPASSWD"]; }]; }
      
      # Network diagnostics (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/ip"; options = ["NOPASSWD"]; }]; }
      
      # Service management (read-only)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/systemctl"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/journalctl"; options = ["NOPASSWD"]; }]; }
      
      # System rebuilds (for Claude Code)
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/nixos-rebuild"; options = ["NOPASSWD"]; }]; }
      { groups = ["wheel"]; commands = [{ command = "/run/current-system/sw/bin/nh"; options = ["NOPASSWD"]; }]; }
    ];

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