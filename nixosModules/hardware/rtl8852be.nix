{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    hardware.enableRedistributableFirmware = true;

    boot.extraModprobeConfig = ''
    '';

    powerManagement.resumeCommands = ''
      if ${pkgs.kmod}/bin/lsmod | grep -q rtw89_8852be; then
        ${pkgs.kmod}/bin/modprobe -r rtw89_8852be rtw89_pci rtw89_core || true
        sleep 1
        ${pkgs.kmod}/bin/modprobe rtw89_8852be || true
      fi
    '';
  };
}

