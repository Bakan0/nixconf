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
    bundles.general.enable = true;  # Server essentials
    bundles.users.enable = true;
    wake-on-lan.enable = true;
    stylix.enable = true;  # Required by home-manager profile
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
       tree  # Keep basic utilities
       yazi  # Terminal file manager
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
    # Essential server tools only
    curl
    git
    nh
    nix-output-monitor  
    openconnect  # VPN client
    tmux
    unzip
    vim
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

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };


  # Server services only
  services.nfs.server.enable = true;
  services.openssh.enable = true;

  # Incompatible with Flakes
  # system.copySystemConfiguration = true;
  system.stateVersion = "24.11";
}

