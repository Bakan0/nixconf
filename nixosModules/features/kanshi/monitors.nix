{ config, lib, ... }:
with lib;
let
  cfg = config.myNixOS.kanshi;

  laptopModels = {
    ASUS_A16_FA617NT = "China Star Optoelectronics Technology Co., Ltd MNG007QA1-1 Unknown";
    # system76_darter8_pro = "make model serial";
  };
  laptopMatch = laptopModels.${cfg.laptopModel};

  parseLogical = res: scale:
    let
      parts = builtins.match "([0-9]+)x([0-9]+)@.*" res;
      w = toInt (elemAt parts 0); # Convert string to integer
      h = toInt (elemAt parts 1);
      wScaled = builtins.floor (w / scale);
      hScaled = builtins.floor (h / scale);
      _ = builtins.trace "parseLogical: res=${res}, scale=${toString scale}, w=${toString w}, h=${toString h}, wScaled=${toString wScaled}, hScaled=${toString hScaled}" null;
    in {
      width = wScaled;
      height = hScaled;
    };

  calcCenterX = primaryRes: primaryScale: secondaryRes: secondaryScale:
    let
      p = parseLogical primaryRes primaryScale;
      s = parseLogical secondaryRes secondaryScale;
      x = builtins.floor ((p.width - s.width) / 2.0); # Use float div for precision, floor to int
      _ = builtins.trace "calcCenterX: p.width=${toString p.width}, s.width=${toString s.width}, x=${toString x}" null;
    in x;
in {
  options.myNixOS.kanshi = {
    laptopResolution = mkOption {
      type = types.str;
      default = "1920x1080@60Hz";
      description = "Laptop native resolution+refresh";
    };
    laptopModel = mkOption {
      type = types.str;
      default = "ASUS_A16_FA617NT";
      description = "Laptop model key for make/model serial lookup";
    };

    sunshineResolution = mkOption {
      type = types.str;
      default = "3104x1664@60Hz";
      description = "Sunshine headless resolution";
    };
    sunshineScale = mkOption {
      type = types.float;
      default = 1.066667;
      description = "Sunshine scale factor";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."kanshi/config".text = ''
      profile laptop-only {
        output "${laptopMatch}" mode ${cfg.laptopResolution} position 0,0
      }

      profile ultrawide-with-laptop {
        output "${laptopMatch}" mode ${cfg.laptopResolution} position 0,0
        output "Philips Consumer Electronics Company PHL 499P9 AU02135004295" mode 5120x1440@29.98Hz position ${toString (calcCenterX cfg.laptopResolution 1.0 "5120x1440@29.98Hz" 1.0)},${toString (- (parseLogical "5120x1440@29.98Hz" 1.0).height)}
      }

      profile ultrawide-only {
        output "Philips Consumer Electronics Company PHL 499P9 AU02135004295" mode 5120x1440@29.98Hz position 0,0
      }

      profile sunshine-streaming-with-laptop {
        output "${laptopMatch}" enable mode ${cfg.laptopResolution} position 0,0
        output sunshine-ultrawide mode --custom ${cfg.sunshineResolution} position ${toString (calcCenterX cfg.laptopResolution 1.0 cfg.sunshineResolution cfg.sunshineScale)},${toString (- (parseLogical cfg.sunshineResolution cfg.sunshineScale).height)} scale ${toString cfg.sunshineScale}
      }

      profile sunshine-streaming-only {
        output sunshine-ultrawide mode --custom ${cfg.sunshineResolution} position 0,0 scale ${toString cfg.sunshineScale}
        output "${laptopMatch}" disable
      }
    '';
  };
}
