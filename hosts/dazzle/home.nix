{ config, lib, pkgs, inputs, ... }:

{
  home = {
    username = "emet";
    homeDirectory = "/home/emet";
    stateVersion = "25.11";
  };

  # Use emet's profile for consistent configuration
  myHomeManager = {
    profiles.emet.enable = true;
    
    # Add any host-specific customizations here
    # Example: bundles.desktop.enable = true;
    # Example: stylix.enable = true;
  };
  
  # Host-specific packages and configurations can go here
  home.packages = with pkgs; [
    # Additional packages specific to dazzle setup
  ];

  # Temporary: Force kitty to use X11 until Wayland EGL/DMA-BUF issue is fixed
  # Error: "failed to import supplied dmabufs: EGL failed to allocate resources"
  # Affects hybrid Intel/AMD graphics on GNOME Wayland
  programs.kitty.settings.linux_display_server = "x11";
}
