{
  pkgs,
  lib,
  ...
}: {
  # Enable general bundle - contains all the system essentials
  myNixOS.bundles.general.enable = lib.mkDefault true;

  # Desktop-specific features (minimal set)
  myNixOS.autologin.enable = lib.mkDefault false;
  myNixOS.pipewire.enable = lib.mkDefault true;
  myNixOS.batteryManagement.enable = lib.mkDefault false;
  myNixOS.virtualisation.enable = lib.mkOverride 900 false;  # Skip for VMs/lean systems
  myNixOS.plymouth-splash.enable = lib.mkDefault false;  # Skip boot splash

  # Disable GNOME and GDM (users bundle enables both for emet by default)
  myNixOS.gnome.enable = lib.mkOverride 900 false;
  myNixOS.gdm.enable = lib.mkOverride 900 false;  # GDM pulls in gnome-shell
  myNixOS.greetd.enable = lib.mkDefault true;  # Use greetd instead - lightest display manager

  # Disable heavy services (override users bundle defaults)
  services.teamviewer.enable = lib.mkOverride 900 false;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config = {
      # Session-specific portal configuration
      hyprland = {
        default = ["hyprland" "gtk"];
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
    # Web browser - single lightweight option
    vivaldi
    vivaldi-ffmpeg-codecs

    # Minimal desktop utilities
    wl-clipboard       # Wayland clipboard utilities
    wtype             # Wayland keyboard input simulation
    wlr-randr         # Wayland display configuration

    # Single lightweight icon theme
    papirus-icon-theme  # Comprehensive, well-maintained, relatively small
  ];

  services = {
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # Skip printing - not needed on lean systems
  };

  hardware = {
    enableAllFirmware = true;

    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  # Minimal fonts - just essentials
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono  # Single nerd font for terminal
    noto-fonts                 # Basic Unicode coverage
    noto-fonts-emoji           # Emoji support
  ];

  security.polkit.enable = true;

  # GNOME keyring PAM configuration for auto-unlock
  security.pam.services.gdm.enableGnomeKeyring = true;
  security.pam.services.gdm-password.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # Enable gnome keyring service
  services.gnome.gnome-keyring.enable = true;

  programs.dconf.enable = true;
}
