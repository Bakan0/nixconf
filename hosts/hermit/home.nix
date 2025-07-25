{ config, pkgs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "25.05";

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

    # Standard directories (optional - these are defaults):
    desktop = "$HOME/Desktop";
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    # templates = "$HOME/Templates";
    # publicShare = "$HOME/Public";
  };

  # Enable your existing modules
  myHomeManager = {
    # Bundles
    bundles.general.enable = true;  # From bundles/general.nix
    bundles.desktop.enable = true;  # From bundles/desktop.nix
    bundles.desktop-full.enable = true;  # From bundles/desktop.nix
    bundles.gaming.enable = true;  # From bundles/general.nix

    # Features
    fish.enable = false;  # Explicitly disable fish
    zsh.enable = true;    # Enable zsh from features/zsh.nix
    git.enable = true;    # Enable git from features/git.nix
    kitty.enable = true;  # If you want kitty terminal

    # Add any other features you want
    firefox.enable = true;
    hyprland.enable = true;
    waybar.enable = true;
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

