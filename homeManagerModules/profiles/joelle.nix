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
    bundles.desktop-gnome.enable = true;

    # Individual features
    nvim.enable = true;
    fish.enable = false;
    zsh.enable = false;
    git.enable = true;
    firefox.enable = true;
    # Stylix disabled - let GNOME handle theming
    stylix.enable = false;
  };

  programs = {
    home-manager.enable = true;
    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
