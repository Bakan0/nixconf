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
    sysadmin.enable = true;
    sysadmin.allowedActions = "anarchy";  # No prompts for curated admin commands
    greetd.enable = true;  # Display manager for Hyprland
    kanshi.enable = true;  # Display management
    tpm2.enable = true;  # TPM2 support for LUKS auto-unlock
    home-users = {
      "emet" = {
        userConfig = ./home.nix;  # Use host-specific home config
        userSettings = {};  # Use default groups from users bundle
      };
    };

    # ZFS support and monitoring tools
    zfs.enable = true;

    # Laptop-specific packages
    bundles.laptop.enable = true;
    virtualisation.enable = true;
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
    hostName = "hearth";
    hostId = "a701a1c0";  # atomic + terracotta theme
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
      remmina
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
    freerdp
    geany
    glxinfo
    neovide
    qbittorrent
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
