{ config, pkgs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "24.11";
  };

  # Use emet's profile for consistent configuration
  myHomeManager.profiles.emet.enable = true;

  # Host-specific overrides (if any)
}

