{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    zfs
    smartmontools
    iotop
    btop
  ];
}