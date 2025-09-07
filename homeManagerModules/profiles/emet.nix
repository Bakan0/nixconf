{ config, pkgs, lib, ... }:

{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      # Core packages moved to general bundle
    ];
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # Enable emet's preferred bundles by default
  myHomeManager = {
    # Bundles
    bundles.general.enable = true;
    bundles.desktop.enable = true;
    bundles.desktop-full.enable = true;
    bundles.gaming.enable = true;
    bundles.databender.enable = true;  # Can be overridden per host

    # Features
    fish.enable = false;  # Explicitly disable fish
    zsh.enable = false;   # Disable zsh - not used
    kitty.enable = true;
    firefox.enable = true;
    hyprland.enable = lib.mkDefault true;
    # Conditional desktop components - only if Hyprland is enabled
    waybar.enable = lib.mkIf config.myHomeManager.hyprland.enable (lib.mkDefault true);
  };

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
