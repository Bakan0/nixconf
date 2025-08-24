{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./zfs-optimizations.nix
    ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sysadmin.enable = true;
      sysadmin.allowedActions = "anarchy";  # No prompts for curated admin commands
    greetd.enable = true;
    hyprland.enable = true;
    stylix.enable = true;
    kanshi = {
      enable = true;
      laptopResolution = "1920x1200@165Hz";
      laptopModel = "ASUS_A16_FA617NT";
    };
    batteryManagement.enable = true;
    tpm2.enable = true;
    amd.enable = true;
    asus.enable = true;
    immersed.enable = true;
    sunshine = {
      enable = true;
      # autoToggleLaptop = true;
    };
    virtualisation = {
      username = "emet";
    };
    home-users = {
      "emet" = {
        # Profile automatically selected as profiles/emet.nix
        userSettings = {
          extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "audio" "avahi" ];
        };
        # Optional per-host overrides:
        # myHomeManager.bundles.databender.enable = false;
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

  time.timeZone = "America/New_York";

  networking = {
    hostName = "hermit";
    hostId = "c0deba5e";
    networkmanager.enable = true;
  };

  # Proper firmware support for AMD GPUs
  hardware = {
    enableRedistributableFirmware = true;

    firmware = with pkgs; [
      linux-firmware        # Contains amdgpu firmware
    ];

    graphics = {
      enable = true;
      enable32Bit = true;

      # AMD-specific packages:
      extraPackages = with pkgs; [
        # AMDGPU drivers:
        mesa
        amdvlk

        # Video acceleration:
        libvdpau-va-gl
        vaapiVdpau

        # OpenCL:
        rocmPackages.clr
        rocmPackages.clr.icd
      ];

      extraPackages32 = with pkgs.driversi686Linux; [
        mesa
        amdvlk
      ];
    };
  };

  system.autoUpgrade.enable = false;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
    ];
  };

  users.users.emet = {
    isNormalUser = true;
    extraGroups = [ "wheel" "incus-admin" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
    ];
    packages = with pkgs; [
       appimage-run
       azure-cli
       azure-cli-extensions.azure-firewall
       # azure-cli-extensions.costmanagement
       azure-cli-extensions.fzf
       # azure-cli-extensions.ip-group
       # azure-cli-extensions.mdp
       # azure-cli-extensions.multicloud-connector
       # azure-cli-extensions.subscription
       # azure-cli-extensions.virtual-network-manager
       # azure-cli-extensions.virtual-wan
       kitty # Terminal emulator, recommended for Hyprland
       microsoft-edge
       mutter
       powershell
       quickemu
       remmina
       sidequest
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
    dunst
    eddie
    fastfetch
    flatpak
    font-awesome
    freerdp
    fwupd
    geany
    glxinfo
    hyprland
    kitty
    libnotify
    mesa-demos
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
    vulkan-tools
    waybar
    wayland
    wget
    wl-clipboard
    xorg.xorgserver
    xwayland
    zip
  ];

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
  services.protonmail-bridge.enable = false;
  services.teamviewer.enable = true;

  system.stateVersion = "25.05";
}

