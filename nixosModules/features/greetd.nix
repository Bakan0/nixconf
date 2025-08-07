{ config, lib, pkgs, ... }:
let cfg = config.myNixOS.greetd;
in {
  config = lib.mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --asterisks --cmd Hyprland";
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

    # Fix Plymouth → Greetd transition gap
    systemd.services.greetd = {
      after = [ "plymouth-quit-wait.service" "getty@tty1.service" ];
      wants = [ "plymouth-quit-wait.service" ];
      conflicts = [ "getty@tty1.service" ];
      serviceConfig = {
        # Start greetd faster
        Type = "idle";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal";
        TTYPath = "/dev/tty1";
        TTYReset = "yes";
        TTYVHangup = "yes";
      };
    };

    # Keep Plymouth running until greetd is actually ready
    systemd.services.plymouth-quit-wait = {
      serviceConfig = {
        ExecStart = [
          ""  # Clear default
          "${pkgs.plymouth}/bin/plymouth quit --wait"
        ];
      };
    };
  };
}

