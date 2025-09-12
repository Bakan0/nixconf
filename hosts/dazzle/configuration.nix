{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      inputs.nixos-hardware.nixosModules.apple-t2
    ];

  hardware.apple.touchBar.enable = true;

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    bundles.users.emet.enable = true;
    batteryManagement.enable = true;
    wake-on-lan.enable = true;
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
    hostId = "da221e01";
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
  
  environment.systemPackages = with pkgs; [
    tailscale
  ];


  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };


  services.protonmail-bridge.enable = true;
  services.teamviewer.enable = true;

  system.stateVersion = "24.11";
}

