{ pkgs, lib, config, ... }:
let
  cfg = config.myNixOS;
in {
  config = lib.mkIf cfg.gnome.enable {
    # Enable the system-provided ydotool service for input simulation (needed for GNOME screenshots)
    systemd.user.services.ydotool = {
      Unit = {
        Description = "ydotool daemon (GNOME only)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        ConditionEnvironment = [ "XDG_CURRENT_DESKTOP=GNOME" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.ydotool}/bin/ydotoold";
        Restart = "on-failure";
        RestartSec = 3;
        TimeoutSec = 180;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # Set up uinput permissions for ydotool - create the device node and set permissions
    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
    '';

    # Ensure uinput module is loaded
    boot.kernelModules = [ "uinput" ];

    # Ensure users who need ydotool are in the input group (handled by users bundle)
  };
}