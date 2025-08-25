{ config, pkgs, ... }:

{
  home = {
    username = "joelle";
    homeDirectory = "/home/joelle";
    stateVersion = "24.05";
  };

  # Use joelle's profile for consistent configuration
  myHomeManager.profiles.joelle.enable = true;

  # Host-specific overrides (if any)
}
