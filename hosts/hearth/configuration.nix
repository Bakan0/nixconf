{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
      ./zfs-optimizations.nix
  ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sysadmin.enable = true;
    sysadmin.allowedActions = "anarchy";  # No prompts for curated admin commands
    greetd.enable = true;  # Display manager for Hyprland
    kanshi.enable = true;  # Display management
    tpm2.enable = true;  # TPM2 support for LUKS auto-unlock
    stylix = {
      enable = true;
      theme = "atomic-terracotta";  # hearth gets the atomic terracotta theme
    };
    home-users = {
      "emet" = {
        # Profile automatically selected as profiles/emet.nix
        userSettings = {
          extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "audio" "avahi" "video" ];
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
      (azure-cli.overrideAttrs (oldAttrs: {
        doInstallCheck = false;
      }))
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
      powershell
      remmina
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
  services.teamviewer.enable = false;

  system.stateVersion = "25.05";
}
