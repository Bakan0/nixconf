{ config, pkgs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "24.11";

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

  # Enable your existing modules
  myHomeManager = {
    # Bundles
    bundles.general.enable = true;  # From bundles/general.nix
    bundles.desktop.enable = true;  # From bundles/desktop.nix

    # Features
    fish.enable = false;  # Explicitly disable fish
    zsh.enable = true;    # Enable zsh from features/zsh.nix
    git.enable = true;    # Enable git from features/git.nix
    kitty.enable = true;  # If you want kitty terminal

    # Add any other features you want
    firefox.enable = true;
    waybar.enable = true;
    hyprland.enable = true;
    # stylix.enable = false;
  };

  programs = {
    home-manager.enable = true;

    # Additional program configs that aren't in your features
    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}

