{
  pkgs,
  lib,
  ...
}: {
  # Enable general bundle - contains all the system essentials
  myNixOS.bundles.general.enable = lib.mkDefault true;

  # Desktop-specific features
  myNixOS.sddm.enable = lib.mkDefault false;
  myNixOS.greetd.enable = lib.mkDefault false;
  myNixOS.autologin.enable = lib.mkDefault false;
  myNixOS.pipewire.enable = lib.mkDefault true;
  myNixOS.batteryManagement.enable = lib.mkDefault false;  # Enable only on laptops
  myNixOS.virtualisation.enable = lib.mkDefault true;
  myNixOS.stylix.enable = lib.mkDefault true;
  myNixOS.plymouth-splash.enable = lib.mkDefault true;

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

  environment.systemPackages = with pkgs; [
    # Web browsers - available to all users
    vivaldi
    vivaldi-ffmpeg-codecs

    # Desktop utilities - available to all users
    meld
    dmidecode
    
    # Icon themes - recent updates, perfect for terracotta theme
    fluent-icon-theme     # Modern fluent design (2025-08-21)
    candy-icons           # Sweet gradients, great for orange! (2025-08-13) 
    qogir-icon-theme      # Flat colorful design (2025-02-15)
    colloid-icon-theme    # Minimal and elegant (2025-02-09)
    vimix-icon-theme      # Material design (2025-02-10)
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

}

