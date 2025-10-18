{ config, lib, ... }:
with lib;
let
  cfg = config.myNixOS.kanshi;

  # Kanshi output format: "Manufacturer Model Serial"
  # If any field is missing, use "Unknown" - see https://man.archlinux.org/man/kanshi.5#PROFILE_DIRECTIVES
  laptopModels = {
    ASUS_A16_FA617NT = "China Star Optoelectronics Technology Co., Ltd MNG007QA1-1 Unknown";
    DELL_XPS13_9300 = "Sharp Corporation 0x14CB Unknown";
    DELL_PRECISION_5530 = "Sharp Corporation 0x149A Unknown";
    APPLE_MBP_16_1 = "Apple Computer Inc Color LCD Unknown";
    KVM_QXL = "Unknown Unknown Unknown";  # QEMU/KVM QXL virtual display
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
    laptopScale = mkOption {
      type = types.float;
      default = 1.0;
      description = "Laptop display scale factor";
    };

    sunshineResolution = mkOption {
      type = types.str;
      default = "3840x2160@60Hz";
      description = "Sunshine headless resolution (4K UHD)";
    };
    sunshineScale = mkOption {
      type = types.float;
      default = 1.0;
      description = "Sunshine scale factor";
    };

    immersedWideResolution = mkOption {
      type = types.str;
      default = "3440x1440@60.00";
      description = "Immersed wide virtual display resolution (1440p ultrawide)";
    };
    immersedSecondaryResolution = mkOption {
      type = types.str;  
      default = "2560x1440@60.00";
      description = "Immersed secondary virtual display resolution";
    };
    immersedWideScale = mkOption {
      type = types.float;
      default = 1.0;
      description = "Immersed wide display scale factor";
    };
    immersedSecondaryScale = mkOption {
      type = types.float;
      default = 1.0;
      description = "Immersed secondary display scale factor";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."kanshi/config".text = ''
      profile laptop {
        output "${laptopMatch}" mode ${cfg.laptopResolution} position 0,0 scale ${toString cfg.laptopScale}
      }

      profile laptop-immersed {
        output "${laptopMatch}" enable mode ${cfg.laptopResolution} position 0,0 scale ${toString cfg.laptopScale}
        output immersed-1 mode --custom ${cfg.immersedWideResolution} position ${toString (calcCenterX cfg.laptopResolution 1.0 cfg.immersedWideResolution cfg.immersedWideScale)},${toString (- (parseLogical cfg.immersedWideResolution cfg.immersedWideScale).height)} scale ${toString cfg.immersedWideScale}
        output immersed-2 mode --custom ${cfg.immersedSecondaryResolution} position ${toString ((calcCenterX cfg.laptopResolution 1.0 cfg.immersedWideResolution cfg.immersedWideScale) + (calcCenterX cfg.immersedWideResolution cfg.immersedWideScale cfg.immersedSecondaryResolution cfg.immersedSecondaryScale))},${toString (- (parseLogical cfg.immersedWideResolution cfg.immersedWideScale).height - (parseLogical cfg.immersedSecondaryResolution cfg.immersedSecondaryScale).height)} scale ${toString cfg.immersedSecondaryScale}
      }

      profile laptop-sunshine {
        output "${laptopMatch}" enable mode ${cfg.laptopResolution} position 0,0 scale ${toString cfg.laptopScale}
        output sunshine-ultrawide mode --custom ${cfg.sunshineResolution} position ${toString (calcCenterX cfg.laptopResolution 1.0 cfg.sunshineResolution cfg.sunshineScale)},${toString (- (parseLogical cfg.sunshineResolution cfg.sunshineScale).height)} scale ${toString cfg.sunshineScale}
      }

      profile laptop-ultrawide-30436 {
        output "${laptopMatch}" disable
        output "Goldstar Company Ltd LG ULTRAWIDE Unknown" mode 3440x1440@60Hz position 0,0
      }

      profile laptop-ultrawide-41127 {
        output "${laptopMatch}" disable
        output "Dell Inc. DELL U3415W PXF7965O1HTL" mode 3440x1440@60Hz position 0,0
      }

      profile laptop-ultrawide-499P9 {
        output "${laptopMatch}" disable
        output "Philips Consumer Electronics Company PHL 499P9 AU02135004295" mode 5120x1440@29.98Hz position ${toString (- (parseLogical "5120x1440@29.98Hz" 1.0).width)},${toString (calcCenterX cfg.laptopResolution 1.0 "5120x1440@29.98Hz" 1.0)}
      }

      profile sunshine {
        output sunshine-ultrawide mode --custom ${cfg.sunshineResolution} position 0,0 scale ${toString cfg.sunshineScale}
        output "${laptopMatch}" disable
      }

      profile ultrawide-30436 {
        output "Goldstar Company Ltd LG ULTRAWIDE Unknown" mode 3440x1440@60Hz position 0,0
      }

      profile ultrawide-41127 {
        output "Dell Inc. DELL U3415W PXF7965O1HTL" mode 3440x1440@60Hz position 0,0
      }

      profile ultrawide-499P9 {
        output "Philips Consumer Electronics Company PHL 499P9 AU02135004295" mode 5120x1440@29.98Hz position 0,0
      }
    '';
  };
}
