{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
      ./zfs-optimizations.nix
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
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  networking = {
    hostName = "ironclad";
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
    acpi
    brightnessctl  
    colorls
    fastfetch
    mesa-demos
    ntfs3g
    openconnect
    qbittorrent
    vulkan-tools
    wl-clipboard
  ];

  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };


  services.protonmail-bridge.enable = false;
  services.teamviewer.enable = false;

  system.stateVersion = "25.05"; # Did you read the comment?
}
