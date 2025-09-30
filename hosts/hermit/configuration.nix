{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./zfs-optimizations.nix
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users = {
      enable = true;
      user = "emet";
    };
    # User configuration handled via home-manager userConfig
    home-users."emet".userConfig = ./home.nix;
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
    hostName = "hermit";
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
    qbittorrent
    sbctl  # Required for lanzaboote secure boot operations
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
