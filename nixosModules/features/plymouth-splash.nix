{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.plymouth-splash;
in {
  config = mkIf cfg.enable {
    # Use liquid theme (which we know works)
    boot.plymouth = {
      enable = true;
      theme = "liquid";
      themePackages = [ pkgs.adi1090x-plymouth-themes ];
      extraConfig = ''
        [Daemon]
        Theme=liquid
        ShowDelay=0
        DeviceTimeout=30
      '';
    };

    boot.kernelParams = [
      "splash"
      "quiet"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}

