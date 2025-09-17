{ config, lib, ... }:
{
  # Enable all transfer scripts
  myHomeManager = {
    xfer-signal.enable = lib.mkDefault true;
    xfer-edge.enable = lib.mkDefault true;
    xfer-fish-history.enable = lib.mkDefault true;
    xfer-obsidian.enable = lib.mkDefault true;
    xfer-libvirt.enable = lib.mkDefault true;
    xfer-claude.enable = lib.mkDefault true;
  };
}