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
    # This host doesn't need databender bundle or gaming
    bundles.databender.enable = false;
    bundles.gaming.enable = false;
  };
}

