{ config, lib, pkgs, ... }:
let cfg = config.myNixOS.greetd;
in {
  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
          user = "greeter";
        };
      };
    };

    # Create greeter user
    users.users.greeter = {
      isSystemUser = true;
      group = "greeter";
    };
    users.groups.greeter = {};

    # Simple log directory
    systemd.tmpfiles.rules = [
      "d /var/log/greetd 0755 greeter greeter -"
    ];
  };
}

