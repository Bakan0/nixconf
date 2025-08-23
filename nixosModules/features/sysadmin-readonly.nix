{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.sysadmin-readonly;
in {
  config = mkIf cfg.enable {
    # Sudoers rules for passwordless execution of read-only system diagnostic commands
    security.sudo.extraRules = [{
      groups = [ "wheel" ];
      commands = [
        # System diagnostics (read-only)
        {
          command = "${pkgs.dmidecode}/bin/dmidecode";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.util-linux}/bin/dmesg";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.util-linux}/bin/lsblk";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.util-linux}/bin/lscpu";
          options = [ "NOPASSWD" ];
        }
        
        # Hardware information (read-only)
        {
          command = "${pkgs.pciutils}/bin/lspci";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.usbutils}/bin/lsusb";
          options = [ "NOPASSWD" ];
        }
        
        # Network diagnostics (read-only)
        {
          command = "${pkgs.iproute2}/bin/ip addr show";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.iproute2}/bin/ip route show";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.iproute2}/bin/ip link show";
          options = [ "NOPASSWD" ];
        }
        
        # Service management (read-only)
        {
          command = "${pkgs.systemd}/bin/systemctl status *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl show *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl list-*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl is-*";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl cat *";
          options = [ "NOPASSWD" ];
        }
        {
          command = "${pkgs.systemd}/bin/journalctl";
          options = [ "NOPASSWD" ];
        }
      ];
    }];

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