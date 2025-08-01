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
    greetd.enable = true;
    hyprland.enable = true;
    stylix.enable = true;
    kanshi.enable = true;
    batteryManagement.enable = true;
    tpm2.enable = true;
    thunderbolt.enable = true;
    amd.enable = true;
    asus.enable = true;
    hardware.rtl8852be.enable = true;
    immersed.enable = true;
    virtualisation = {
      username = "emet";
    };
    home-users = {
      "emet" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" ];
        };
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

  networking = {
    hostName = "hermit";
    hostId = "c0deba5e";
    networkmanager.enable = true;
    # firewall = {
    #   allowedTCPPorts = [
    #     47989  # Sunshine HTTPS Web UI
    #     47984  # Sunshine HTTP Web UI  
    #     47990  # Sunshine RTSP
    #     48010  # Sunshine additional TCP
    #   ];
    #   allowedUDPPorts = [
    #     47998  # Sunshine Video
    #     47999  # Sunshine Control
    #     48000  # Sunshine Audio
    #     48010  # Sunshine Mic (if needed)
    #   ];
    # };
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
        mesa.drivers
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
    curl
    dunst
    eddie
    fastfetch
    flatpak
    font-awesome
    freerdp
    fwupd
    git
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
  services.protonmail-bridge.enable = false;
  services.teamviewer.enable = false;

  system.stateVersion = "25.05";
}

