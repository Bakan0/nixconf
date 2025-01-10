{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkOption types;
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
        # workspace = mkOption {
        #   type = types.nullOr types.str;
        #   default = null;
        # };
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

  config = {
    myHomeManager.monitors = {
      "desc:Philips Consumer Electronics Company PHL 499P9" = {
        primary = true;
        width = 5120;
        height = 1440;
        refreshRate = 29.979;
        x = 0;
        y = 0;
        enabled = true;
      };
    };

    myHomeManager.workspaces = {
      "1" = {
        monitorId = 1;
        autostart = [];
      };
      "2" = {
        monitorId = 1;
        autostart = [];
      };
      "3" = {
        monitorId = 1;
        autostart = [ "signal" "vivaldi-stable" ];
      };
      "4" = {
        monitorId = 1;
        autostart = [ "microsoft-edge" ];
      };
      "5" = {
        monitorId = 1;
        autostart = [ "teamviewer" ];
      };
    };

    wayland.windowManager.hyprland.extraConfig = ''
      # Auto handle monitors
      monitor = eDP-1, preferred, auto, 1
      monitor = desc:Philips Consumer Electronics Company PHL 499P9, 5120x1440@29.979, 0x0, 1
    '';
  };
}
