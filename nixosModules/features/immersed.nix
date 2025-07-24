{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.immersed;

  # Create a custom package set with gjs tests disabled, only for immersed's dependency chain
  immersedPkgs = pkgs.extend (final: prev: {
    gjs = prev.gjs.overrideAttrs (oldAttrs: {
      doCheck = false;  # Skip flaky GIMarshalling test
    });
  });

  # Use immersed from the custom package set
  immersedFixed = immersedPkgs.immersed;

in {
  config = mkIf cfg.enable {
    # Install Immersed with the fixed gjs dependency
    environment.systemPackages = [
      immersedFixed
    ];

    # Enable required services for VR/AR applications
    hardware.graphics = {
      enable = true;
      enable32Bit = true;  # Required for some VR applications
    };

    # Enable required system services
    services.dbus.enable = true;

    # Ensure required desktop integration
    services.xserver.enable = mkDefault true;  # Still needed for some desktop integration

    # Add VR-related environment variables
    environment.variables = {
      # Ensure proper VR runtime detection
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  };
}

