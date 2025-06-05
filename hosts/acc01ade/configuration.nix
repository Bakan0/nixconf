{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
      ./nextcloud-nginx.nix
      ./jellyfin.nix
    ];
  
  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sddm.enable = true;
    hyprland.enable = true;
    stylix.enable = true;
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
    supportedFilesystems = [ "zfs" ];
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    kernelParams = [
       "zfs.zfs_arc_max=25769803776"  # 24GB max ARC size
       "intel_iommu=on" # Enable IOMMU
       "iommu=pt"       # Set IOMMU to passthrough mode
    ];
    initrd.systemd.enable = true;
    zfs.forceImportRoot = false;
  };

  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    trim.enable = true;
  };

  virtualisation.incus.enable = true;
  networking.nftables.enable = true;
  networking.firewall = {
    # NFSv4 nas share
    allowedTCPPorts = [ 2049];
    allowedUDPPorts = [ 2049];
    trustedInterfaces = [ "incusbr0" ];
  };

  networking = {
      hostName = "acc01ade";
      hostId = "acc01ade";
      networkmanager.enable = false;
  
      # Create bond interface
      bonds.bond0 = {
        interfaces = [ "eno1" "eno2" ];
        driverOptions = {
          mode = "802.3ad";
          miimon = "100";
          lacp_rate = "fast";
          xmit_hash_policy = "layer3+4";
        };
      };
  
      # Bridge configuration
      bridges = {
        "incusbr0" = {
          interfaces = [ "bond0" ];
          rstp = true;  # Enable rapid spanning tree protocol
        };
      };
  
      # Interface configuration
      interfaces = {
        eno1.useDHCP = false;
        eno2.useDHCP = false;
        bond0.useDHCP = false;
        incusbr0 = {
          ipv4.addresses = [{
            address = "10.17.19.250";
            prefixLength = 24;
          }];
          useDHCP = false;
        };
      };
  
      defaultGateway = "10.17.19.252";
      nameservers = [ "10.17.19.197" "10.17.19.199" ];
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
       # azure-cli
       bitwarden-desktop
       evolution
       evolution-ews
       kitty # Terminal emulator, recommended for Hyprland
       meld
       mutter
       obsidian
       onlyoffice-bin_latest
       powershell
       remmina
       sidequest
       tree
       # vivaldi
       # vivaldi-ffmpeg-codecs
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

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    colorls
    curl
    dunst
    fastfetch
    flatpak
    font-awesome
    freerdp
    fwupd
    git
    hypridle
    hyprland
    hyprlock
    kitty
    libnotify
    neovide
    networkmanagerapplet
    nh
    nix-output-monitor
    ntfs3g
    openconnect
    pavucontrol
    rofi-wayland
    swww
    tailscale
    # teamviewer
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


  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # services.flatpak.enable = true;
  services.fwupd.enable = true;
  services.nfs.server.enable = true;
  services.openssh.enable = true;
  services.protonmail-bridge.enable = true;
  # services.teamviewer.enable = true;

  # Incompatible with Flakes
  # system.copySystemConfiguration = true;
  system.stateVersion = "24.11";
}

