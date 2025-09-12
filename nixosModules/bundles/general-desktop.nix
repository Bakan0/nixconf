{
  pkgs,
  lib,
  ...
}: {
  # System-wide nixpkgs configuration (moved from Home Manager)
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Nix experimental features (correct location)
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Automatic generation cleanup - keep max 17 generations  
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # Automatically clean up old boot entries (keep 17 generations)
  boot.loader.systemd-boot.configurationLimit = 17;

  myNixOS.sddm.enable = lib.mkDefault false;
  myNixOS.greetd.enable = lib.mkDefault false;
  myNixOS.autologin.enable = lib.mkDefault true;
  myNixOS.pipewire.enable = lib.mkDefault true;
  myNixOS.batteryManagement.enable = lib.mkDefault false;  # Enable only on laptops
  myNixOS.powerManagement.enable = lib.mkDefault true;
  myNixOS.virtualisation.enable = lib.mkDefault true;
  myNixOS.stylix.enable = lib.mkDefault true;
  myNixOS.plymouth-splash.enable = lib.mkDefault true;

  # US Central time zone
  time.timeZone = lib.mkDefault "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
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

  console = {
    earlySetup = true;
    font = "sun12x22";
    useXkbConfig = true;
  };

  security.rtkit.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config = {
      preferred = {
        default = ["hyprland" "gtk"];
      };
      hyprland = {
        "org.freedesktop.impl.portal.FileChooser" = "hyprland";
        "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
        "org.freedesktop.impl.portal.Screenshot" = "hyprland";
      };
      common = {
        "org.freedesktop.impl.portal.FileChooser" = "gtk";
      };
    };
  };

  environment.etc.hosts.mode = "0644";

  environment.systemPackages = with pkgs; [
    # Web browsers - available to all users
    vivaldi
    vivaldi-ffmpeg-codecs

    # Desktop utilities - available to all users
    meld
    dmidecode
  ];

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # GVFS for file manager integration with cloud storage
    gvfs.enable = true;

    # Printing configuration - fixed to not block boot
    printing = {
      enable = true;
      browsing = true;
      browsedConf = ''
        BrowseDNSSDSubTypes _cups,_print
        BrowseProtocols cups dnssd
      '';
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;  # This allows user applications to publish services
        workstation = true;
      };
    };

    upower.enable = true;
  };

  hardware = {
    enableAllFirmware = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Fixed printer configuration - won't block boot if network unavailable
    printers = {
      ensurePrinters = [{
        name = "gw-hp-clj-mfp-m283fdw";
        location = "Home";
        deviceUri = "ipps://10.17.19.145/ipp/print";
        model = "everywhere";
        description = "HP Color LaserJet MFP M283fdw";
      }];
      ensureDefaultPrinter = "gw-hp-clj-mfp-m283fdw";
    };
  };

  # Make printer services non-blocking during boot
  systemd.services.cups-browsed = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Make ensure-printers service non-blocking and optional
  systemd.services.ensure-printers = {
    wantedBy = lib.mkForce [ ];
    after = [ "cups.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      TimeoutStartSec = "10s";
      Restart = "no";
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.mononoki
    nerd-fonts.jetbrains-mono
    nerd-fonts.iosevka
    nerd-fonts.fira-code
    # fonts for swaybar
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
    source-han-sans
    source-han-sans-japanese
    source-han-serif-japanese
    cm_unicode
    corefonts
  ];

  security.polkit.enable = true;

  programs.dconf.enable = true;

  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}

