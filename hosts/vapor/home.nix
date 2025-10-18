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
    bundles.lean-desktop.enable = true;  # Override heavy packages from profile
  };
}
