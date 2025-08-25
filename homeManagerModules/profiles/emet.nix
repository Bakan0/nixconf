{ config, pkgs, ... }:

{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      jq
      bat
      eza
      fzf
      htop
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
    zsh.enable = true;
    kitty.enable = true;
    firefox.enable = true;
    hyprland.enable = true;
    waybar.enable = true;
  };

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
