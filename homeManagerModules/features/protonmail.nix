{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myHomeManager.protonmail;
in {
  # Remove the options declaration since it's handled by extendModules
  config = {
    home.packages = with pkgs; [
      protonmail-bridge
    ];

    systemd.user.services.protonmail-bridge = {
      Unit = {
        Description = "Protonmail Bridge";
        After = [ "network.target" ];
      };

      Service = {
        ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Enable gnome-keyring for secrets management
    services.gnome-keyring = {
      enable = true;
      components = [ "secrets" "ssh" ];
    };
  };
}
