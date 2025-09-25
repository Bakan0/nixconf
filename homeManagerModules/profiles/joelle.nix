{ config, pkgs, ... }:

{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      # Core packages now provided by bundles
    ];
  };

  # Joelle's minimal configuration
  myHomeManager = {
    # GNOME-compatible desktop bundle (includes general but avoids Hyprland-specific configs)
    bundles.desktop = {
      enable = true;
      gnome.enable = true;
    };

    # Individual features
    nvim.enable = true;
    yazi.enable = false;  # Explicitly disable yazi for GNOME
    zsh.enable = false;
    git.enable = true;
    firefox.enable = true;
    # Stylix with crimson-noir theme for Joelle
    stylix = {
      enable = true;
      theme = "crimson-noir";
      iconTheme = "dracula";  # Gothic dark with red accents
    };
  };
  programs = {
    home-manager.enable = true;
    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
