{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sddm.enable = true;
    hyprland.enable = true;
    stylix.enable = true;
    kanshi.enable = true;
    batteryManagement.enable = true;
    tpm2.enable = true;
    home-users = {
      "emet" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = [ "networkmanager" "wheel" ];
        };
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

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
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
    curl
    dunst
    eddie
    fastfetch
    flatpak
    font-awesome
    freerdp
    fwupd
    git
    hyprland
    kitty
    libnotify
    neovide
    networkmanagerapplet
    nh
    nix-output-monitor
    ntfs3g
    openconnect
    pavucontrol
    qbittorrent
    rofi-wayland
    swww
    teamviewer
    tmux
    unzip
    vim
    waybar
    wayland
    wget
    wl-clipboard
    xorg.xorgserver
    xwayland
    zip
  ];

  environment.variables.EDITOR = "nvim";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

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

