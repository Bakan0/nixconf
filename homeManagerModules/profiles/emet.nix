{ config, pkgs, lib, myLib, ... }:

{
  imports = [
    ./xfer-scripts.nix
  ];
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


  # Enable emet's preferred bundles by default (can be overridden per host)
  myHomeManager = {
    # Bundles
    bundles.general.enable = lib.mkDefault true;
    bundles.desktop.enable = lib.mkDefault true;
    bundles.desktop-full.enable = lib.mkDefault true;
    bundles.gaming.enable = lib.mkDefault true;
    bundles.databender.enable = lib.mkDefault true;

    # Features
    fish.enable = false;  # Explicitly disable fish
    zsh.enable = false;   # Disable zsh - not used
    kitty.enable = true;
    firefox.enable = true;
    hyprland.enable = lib.mkDefault true;
    microsoft.enable = lib.mkDefault true;  # Default for emet - override per host if needed
    nextcloud-client = {
      enable = lib.mkDefault true;
      symlinkUserDirs = lib.mkDefault true;  # OneDrive-style integration
    };
    # Conditional desktop components - only if Hyprland is enabled
    waybar.enable = lib.mkIf config.myHomeManager.hyprland.enable (lib.mkDefault true);
    
    # Stylix theme preference for emet
    stylix.enable = lib.mkDefault true;
  };

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
