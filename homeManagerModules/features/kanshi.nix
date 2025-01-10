{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myHomeManager.features.kanshi;
in {
  options.myHomeManager.features.kanshi = {
    enable = mkEnableOption "Kanshi display management";
  };

  config = mkIf cfg.enable {
    # Just install kanshi
    home.packages = [ pkgs.kanshi ];

    # Add to Hyprland startup
    wayland.windowManager.hyprland.settings = {
      exec-once = ["kanshi"];
    };
  };
}

