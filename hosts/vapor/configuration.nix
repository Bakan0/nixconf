{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./zfs-optimizations.nix
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  myNixOS = {
    bundles.lean-desktop.enable = true;  # Lean version without heavy packages
    bundles.users = {
      enable = true;
      user = "emet";
    };
    hyprland.enable = true;  # Hyprland is much lighter than GNOME (~500MB vs ~3GB)
    impermanence.enable = true;
    # User configuration handled via home-manager userConfig
    home-users."emet".userConfig = ./home.nix;

    # Kanshi configuration for KVM QXL virtual display
    kanshi = {
      laptopModel = "KVM_QXL";
      laptopResolution = "1920x1080@60Hz";
      laptopScale = 1.0;
    };
  };

  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 17;
    };
    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  networking = {
    hostName = "vapor";
    networkmanager.enable = true;
  };

  system.autoUpgrade.enable = false;

  # User configuration provided by user bundle - no manual setup needed

  # Enable flakes and allow unfree
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nixpkgs.config.allowUnfree = true;

  # Most packages provided by general-desktop bundle
  environment.systemPackages = with pkgs; [
    # Additional packages not in bundles
  ];

  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };



  system.stateVersion = "25.05"; # Did you read the comment?
}
