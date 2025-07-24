{
  pkgs,
  lib,
  ...
}: let

in {
  home.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    # Set default to use eGPU when available
    DRI_PRIME = "1"; # This will be overridden by scripts when eGPU not available
  };

  programs.mangohud.enable = true;

  home.packages = with pkgs; [
    # Original packages
    steam
    steam-run
    protonup-ng
    gamemode
    dxvk
    bottles
    steamtinkerlaunch
    er-patcher

    # addition attempt at VR
    sunshine # to pair with moonlight sideload
  ];

  myHomeManager.impermanence.cache.directories = [
    ".local/share/Steam"
    ".local/share/bottles"
    ".config/r2modmanPlus-local"
    "Games"
    ".config/heroic"
  ];
}

