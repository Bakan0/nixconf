{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    bundles.users.emet.enable = true;
    kanshi.laptopResolution = "1920x1080@60Hz";
    batteryManagement.enable = true;
    immersed.enable = true;
    virtualisation = {
      username = "emet";
    };
  };

  boot = {
    kernelParams = [
      "zfs.zfs_arc_max=25769803776"  # 24GB max ARC size
      "intel_iommu=on"
    ];
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  networking = {
    hostName = "nighthawk";
    hostId = "5caff01d";
    networkmanager.enable = true;
    firewall = {
      allowedTCPPorts = [
        47989  # Sunshine HTTPS Web UI
        47984  # Sunshine HTTP Web UI  
        47990  # Sunshine RTSP
        48010  # Sunshine additional TCP
      ];
      allowedUDPPorts = [
        47998  # Sunshine Video
        47999  # Sunshine Control
        48000  # Sunshine Audio
        48010  # Sunshine Mic (if needed)
      ];
    };
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

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.fwupd.enable = true;
  services.openssh.enable = true;
  services.protonmail-bridge.enable = true;
  services.teamviewer.enable = true;

  system.stateVersion = "24.11";
}

