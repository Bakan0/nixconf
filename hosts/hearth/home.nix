{ config, lib, pkgs, inputs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "25.05";
  };

  # Use emet's profile for consistent configuration
  myHomeManager.profiles.emet.enable = true;

  # Host-specific overrides (if any)
  myHomeManager = {
    bundles.general.enable = true;
    
    # hearth-specific customizations
    # Terracotta/atomic theme preferences will be handled by stylix
  };
  
  # Host-specific packages and configurations can go here
  home.packages = with pkgs; [
    # Additional packages specific to hearth setup
  ];
}
