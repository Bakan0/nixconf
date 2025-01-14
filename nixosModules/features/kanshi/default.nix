{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.kanshi;
in {
  imports = [
    ./monitors.nix
    ./scripts.nix
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.kanshi ];

    systemd.user.services.kanshi = {
      description = "kanshi daemon";
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      after = [ "hyprland-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.kanshi}/bin/kanshi -c /etc/kanshi/config";
        Restart = "always";
        RestartSec = 5;
        Environment = "WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000";
      };
    };
  };
}
