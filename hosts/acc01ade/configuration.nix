{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./nvidia.nix
    ];
  
  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sddm.enable = true;
    hyprland.enable = true;
    home-users = {
      "emet" = {
        userConfig = ./home.nix;
        userSettings = {
          extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "adbusers" ];
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
  networking.firewall.trustedInterfaces = [ "incusbr0" ];


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
  
      # Basic bridge configuration
      bridges = {
        "incusbr0" = {
          interfaces = [ "bond0" ];
        };
      };
  
      # Interface configuration
      interfaces.incusbr0 = {
        ipv4.addresses = [{
          address = "10.17.19.250";
          prefixLength = 24;
        }];
        useDHCP = false;
      };
  
      defaultGateway = "10.17.19.252";
      nameservers = [ "10.17.19.197" "10.17.19.199" ];
  };

  # Fonts for swaybar
  fonts = {
    packages = with pkgs; [
      nerd-fonts.mononoki
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      font-awesome
      source-han-sans
      source-han-sans-japanese
      source-han-serif-japanese
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" "Source Han Serif" ];
      sansSerif = [ "Noto Sans" "Source Han Sans" ];
    };
  };
  
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "sun12x22";
    useXkbConfig = true;
  };

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;
  
  # Enable Hyprland!
  # programs.hyprland = {
  #   enable = true;
  #   package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  #   portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  #   xwayland.enable = true;
  # };

  #  xdg.portal = {
  #    enable = true;
  #    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  #  };

  # environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  services.printing.enable = true;

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
       bitwarden-desktop
       evolution
       evolution-ews
       kitty # Terminal emulator, recommended for Hyprland
       meld
       microsoft-edge
       mutter
       obsidian
       onlyoffice-bin_latest
       powershell
       remmina
       sidequest
       signal-desktop
       tree
       vivaldi
       vivaldi-ffmpeg-codecs
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
    neovim
    networkmanagerapplet
    nh
    nix-output-monitor
    ntfs3g
    openconnect
    pavucontrol
    rofi-wayland
    swww
    tailscale
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


  # services.flatpak.enable = true;
  services.fwupd.enable = true;
  services.openssh.enable = true;
  services.protonmail-bridge.enable = true;
  services.teamviewer.enable = true;

  # Incompatible with Flakes
  # system.copySystemConfiguration = true;
  system.stateVersion = "24.11";
}

