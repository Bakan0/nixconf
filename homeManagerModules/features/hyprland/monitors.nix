{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types mkIf;
  cfg = config.myHomeManager;
in {
  options.myHomeManager.monitors = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        primary = mkOption {
          type = types.bool;
          default = false;
        };
        width = mkOption {
          type = types.int;
          example = 1920;
        };
        height = mkOption {
          type = types.int;
          example = 1080;
        };
        refreshRate = mkOption {
          type = types.float;
          default = 60;
        };
        x = mkOption {
          type = types.int;
          default = 0;
        };
        y = mkOption {
          type = types.int;
          default = 0;
        };
        enabled = mkOption {
          type = types.bool;
          default = true;
        };
      };
    });
    default = {};
  };

  options.myHomeManager.workspaces = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        monitorId = mkOption {
          type = types.int;
          default = false;
        };
        autostart = mkOption {
          type = types.listOf types.str;
          default = [];
        };
      };
    });
    default = {};
  };

  options.myHomeManager.eGPU = {
    enableVirtualDisplays = mkOption {
      type = types.bool;
      default = false;
      description = "Enable virtual displays for eGPU when connected";
    };
  };

  config = {
    myHomeManager.eGPU.enableVirtualDisplays = true;

    myHomeManager.workspaces = {
      "1" = {
        monitorId = 1;
        autostart = [ "kitty --execute btop" ];
      };
      "2" = {
        monitorId = 1;
        autostart = [ ];
      };
      "3" = {
        monitorId = 1;
        autostart = [ "signal" "vivaldi-stable" ];
      };
      "4" = {
        monitorId = 1;
        autostart = [ ];
      };
      "5" = {
        monitorId = 1;
        autostart = [ "" ];
      };
    };

    # Create eGPU management scripts
    home.packages = with pkgs; [
    ];

    wayland.windowManager.hyprland.extraConfig = ''
      # Auto handle monitors with v2 syntax
      monitor=,preferred,auto,1
    '';
  };
}
