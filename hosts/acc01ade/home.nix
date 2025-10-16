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
    # This host doesn't need desktop or graphics-performance bundles
    bundles.databender.enable = false;
    bundles.graphics-performance.enable = false;
    bundles.desktop.enable = false;         # No browsers, MIME associations, desktop apps

    # Desktop components disabled via bundles.desktop.enable = false

    # Server doesn't need Microsoft Azure tools
    microsoft.enable = false;

    # Enable claude-code explicitly (normally comes from databender bundle)
    claude-code-latest.enable = true;
  };
}

