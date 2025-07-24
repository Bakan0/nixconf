{ config, lib, ... }:

with lib;
let
  cfg = config.myNixOS.kanshi;
in {
  config = mkIf cfg.enable {
    environment.etc."kanshi/config".text = ''
      # This profile only matches when laptop is ACTUALLY enabled
      profile ultrawide-with-laptop {
        output "Philips Consumer Electronics Company PHL 499P9 AU02135004295" mode 5120x1440@29.98Hz position 0,0
        output eDP-1 mode 1920x1080@60Hz position 5120,0
      }
    
      # This profile matches when ultrawide connected but laptop disabled
      profile ultrawide-only {
        output "Philips Consumer Electronics Company PHL 499P9 AU02135004295" mode 5120x1440@29.98Hz position 0,0
        # No eDP-1 line = kanshi won't manage it
      }
    
      profile laptop-only {
        output eDP-1 mode 1920x1080@60Hz position 0,0
      }
    '';
  };
}

