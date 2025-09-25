{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./zfs-optimizations.nix
    inputs.nixos-hardware.nixosModules.apple-t2
  ];


  # Enable T2 firmware for WiFi/Bluetooth
  hardware.apple-t2.firmware.enable = true;

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users = {
      enable = true;
      user = "emet";
    };
    # User configuration handled via home-manager userConfig
    home-users."emet".userConfig = ./home.nix;

    # ZFS support and monitoring tools
    zfs.enable = true;

    # Laptop-specific packages
    bundles.laptop.enable = true;

    # Display management for MacBookPro16,1
    kanshi = {
      enable = true;
      laptopModel = "APPLE_MBP_16_1";
      laptopResolution = "3072x1920@60Hz";
      laptopScale = 1.333333;
    };

    # Apple T2 MacBook support for early boot keyboard/trackpad
    apple = {
      enable = true;
      modelOverrides = "T2";
      # TPM unlock disabled - use apple-tpm-cleanup to remove all swtpm state
    };

    # TPM support disabled - was causing boot hangs
    # tpm2.enable = true;

    # Intel graphics support
    intel.enable = true;

    # AMD graphics support
    amd = {
      enable = true;
      supergfxMode = "Hybrid";
      primaryGpu = "amd";
      driPrimeAmd = "0";
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  networking = {
    hostName = "dazzle";
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
  ];

  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };



  system.stateVersion = "25.11"; # Did you read the comment?
}
