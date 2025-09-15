{ config, pkgs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "24.11";
  };

  # Use emet's profile for consistent configuration
  myHomeManager.profiles.emet.enable = true;

  # Host-specific overrides for server
  myHomeManager = {
    # This host doesn't need desktop or gaming bundles
    bundles.databender.enable = false;
    bundles.gaming.enable = false;
    bundles.desktop.enable = false;         # No browsers, MIME associations, desktop apps
    bundles.desktop-full.enable = false;    # No additional desktop applications
    
    # Disable desktop components on server
    hyprland.enable = false;
    waybar.enable = false;
    
    # Server doesn't need Microsoft Azure tools
    microsoft.enable = lib.mkForce false;
  };
}

