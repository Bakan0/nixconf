{ config, lib, ... }:

with lib;
let
  cfg = config.myNixOS.kanshi;
in {
  config = mkIf cfg.enable {
    environment.etc."kanshi/config".text = ''
      profile dual {
        output "DP-1" mode 5120x1440@29.979 position 0,0
        output "eDP-1" mode 1920x1080@60 position 5120,0
      }

      profile external {
        output "DP-1" mode 5120x1440@29.979 position 0,0
        output "eDP-1" disable
      }

      profile laptop {
        output "eDP-1" mode 1920x1080@60 position 0,0
      }
    '';
  };
}
