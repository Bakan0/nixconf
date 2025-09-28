{ config, lib, pkgs, inputs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "25.05";
  };

  # Use emet's profile for consistent configuration
  myHomeManager = {
    profiles.emet.enable = true;
    bundles.desktop = {
      enable = true;
      gnome.enable = true;
    };

    # Add any host-specific customizations here
    # Example: stylix.enable = true;
  };
  
  # Host-specific packages and configurations can go here
  home.packages = with pkgs; [
    # Additional packages specific to hearth setup
    gnucash
  ];
}
