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

  myNixOS.sddm.enable = lib.mkDefault false;
  myNixOS.greetd.enable = lib.mkDefault false;
  myNixOS.autologin.enable = lib.mkDefault true;
  myNixOS.pipewire.enable = lib.mkDefault true;
  myNixOS.batteryManagement.enable = lib.mkDefault true;
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
      openFirewall = true;
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

  # Make printer service non-blocking during boot
  systemd.services.cups-browsed = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s";
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

