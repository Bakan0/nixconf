{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users = {
      enable = true;
      user = "emet";
    };
    kanshi = {
      laptopModel = "DELL_XPS13_9300";
      laptopResolution = "1920x1200@59.95Hz";
    };
    virtualisation.enable = true;
    wake-on-lan.enable = true;

    # Laptop-specific packages
    bundles.laptop.enable = true;
    usb-reset.enable = true;  # USB bus reset utilities
    home-users = {
      "emet" = {
        userConfig = ./home.nix;  # Use host-specific home config
        userSettings = {};  # Use default groups from users bundle
      };
    };
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  networking = {
    hostName = "tyr";
    networkmanager.enable = true;
  };

  system.autoUpgrade.enable = false;


  # Enable flakes and allow unfree
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nixpkgs.config.allowUnfree = true;



  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };


  services.protonmail-bridge.enable = true;
  services.teamviewer.enable = true;

  # TeamViewer wrapper script for Wayland compatibility
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "teamviewer-wayland" ''
      export QT_QPA_PLATFORM="wayland;xcb"
      export XDG_SESSION_TYPE="wayland"
      export XDG_CURRENT_DESKTOP="Hyprland"
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
      exec ${teamviewer}/bin/teamviewer "$@"
    '')
  ];

  system.stateVersion = "24.11";
}

