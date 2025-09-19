{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./zfs-optimizations.nix
    ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users = {
      enable = true;
      user = "emet";
    };
    greetd.enable = true;  # Display manager for Hyprland
    kanshi = {
      laptopModel = "ASUS_A16_FA617NT";
      laptopResolution = "1920x1200@165Hz";
    };
    batteryManagement.enable = true;
    tpm2.enable = true;
    amd = {
      enable = true;
      supergfxMode = "Hybrid";
    };
    asus.enable = true;
    immersed.enable = true;
    sunshine = {
      enable = true;
      # autoToggleLaptop = true;
    };
    powerManagement.enable = false;  # TEMP DEBUG
    virtualisation.enable = true;
    wake-on-lan.enable = true;
    home-users = {
      "emet" = {
        userConfig = ./home.nix;  # Use host-specific home config
        userSettings = {};  # Use default groups from users bundle
      };
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

  # time.timeZone = "America/New_York";

  networking = {
    hostName = "hermit";
    hostId = "c0deba5e";
    networkmanager.enable = true;
  };


  system.autoUpgrade.enable = false;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
    ];
  };

  users.users.emet = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
    ];
    packages = with pkgs; [
       appimage-run
       kitty # Terminal emulator, recommended for Hyprland
       mutter
       quickemu
       remmina
       sidequest
       teamviewer
       tree
       yazi
    ];
  };

  # Enable flakes and allow unfree
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-sdk-6.0.428"
    "dotnet-runtime-6.0.36"
    ];

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    colorls
    eddie
    fastfetch
    freerdp
    geany
    glxinfo
    mesa-demos
    neovide
    nh
    nix-output-monitor
    ntfs3g
    openconnect
    qbittorrent
    tmux
    unzip
    vim
    vulkan-tools
    wget
    zip
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

  system.stateVersion = "25.05";
}

