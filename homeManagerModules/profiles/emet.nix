{ config, pkgs, lib, myLib, ... }:

{
  # No additional imports needed - using individual script feature modules
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
    # Bundles - desktop with BOTH Hyprland and GNOME
    bundles.desktop = {
      enable = lib.mkDefault true;
      hyprland.enable = lib.mkDefault true;
      gnome = {
        enable = lib.mkDefault true;
        tiling.enable = lib.mkDefault true;  # Hyprland-like tiling for GNOME
      };
    };
    bundles.graphics-performance.enable = lib.mkDefault true;
    bundles.databender.enable = lib.mkDefault true;
    bundles.xfer-scripts.enable = lib.mkDefault true;

    # Features
    zsh.enable = false;   # Legacy vimjoyer code - not used
    firefox.enable = true;
    # hyprland and waybar now handled by desktop-hyprland bundle
    microsoft.enable = lib.mkDefault true;  # Default for emet - override per host if needed
    nextcloud-client = {
      enable = lib.mkDefault true;
      symlinkUserDirs = lib.mkDefault true;  # OneDrive-style integration
    };
    
    # Stylix theme preference for emet
    stylix = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "atomic-terracotta";
      iconTheme = lib.mkDefault "numix";  # Professional with orange accents
    };

    # Transfer scripts now enabled via bundles.xfer-scripts
  };

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
