{ config, lib, pkgs, ... }:
let cfg = config.myNixOS.thunderbolt;
in {
  config = lib.mkIf cfg.enable {
    # Enable Thunderbolt support
    services.hardware.bolt.enable = true;

    # Set Thunderbolt security to none for faster boot
    boot.kernelParams = [ "thunderbolt.security=none" ];

    # Ensure USB4 module loads early (thunderbolt already in your hardware-configuration.nix)
    boot.kernelModules = [ "usb4" ];
  };
}

