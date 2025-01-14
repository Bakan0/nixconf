{ config, lib, ... }:

with lib;
let
  cfg = config.myNixOS.kanshi;
in {
  config = mkIf cfg.enable {
    environment.etc."kanshi/config".text = ''
      profile dual {
        output DP-1 {
          mode 5120x1440@29.979Hz  # Added Hz to ensure exact refresh rate
          position 0,0             # Ultrawide at origin
        }
        output eDP-1 {
          mode 1920x1080@60Hz
          position 5120,0         # Laptop screen to the right of ultrawide
        }
      }

      profile external {
        output DP-1 {
          mode 5120x1440@29.979Hz  # Added Hz to ensure exact refresh rate
          position 0,0
        }
        output eDP-1 disable
      }

      profile laptop {
        output eDP-1 {
          mode 1920x1080@60Hz
          position 0,0
        }
      }
    '';
  };
}
