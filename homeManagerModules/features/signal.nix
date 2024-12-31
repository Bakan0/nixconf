{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.myHomeManager.signal;
in {

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      signal-desktop
    ];
  };
}

