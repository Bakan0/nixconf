# In your plymouth-splash module - just add the critical kernel params:
{ config, lib, pkgs, ... }:
let cfg = config.myNixOS.plymouth-splash;
in {
  config = lib.mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      theme = "liquid";
      themePackages = [ pkgs.adi1090x-plymouth-themes ];
    };

    # The ONLY fix needed - suppress stage 1 messages
    boot.kernelParams = [
      "quiet"
      "splash" 
      "rd.systemd.show_status=false"
    ];

    boot.initrd.verbose = false;
  };
}
