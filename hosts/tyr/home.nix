{ config, pkgs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "24.11";
  };

  # Use emet's profile for consistent configuration
  myHomeManager.profiles.emet.enable = true;

  # Host-specific overrides
  myHomeManager = {
    # This host doesn't need gaming bundle
    bundles.gaming.enable = false;
    
    # Enable Microsoft Azure tools for work
    microsoft.enable = true;
  };
}

