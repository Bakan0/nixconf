{
  pkgs,
  lib,
  ...
}: {
  # Hyprland-specific desktop bundle
  # Includes desktop bundle (which includes general) plus Hyprland-specific configs

  myHomeManager = {
    bundles.desktop.enable = lib.mkDefault true;

    # Hyprland and related components
    hyprland.enable = lib.mkDefault true;
    waybar.enable = lib.mkDefault true;  # Hyprland status bar
    rofi.enable = lib.mkDefault true;     # Hyprland launcher
    xremap.enable = lib.mkDefault false;

    # Additional desktop apps for Hyprland users
    vesktop.enable = lib.mkDefault true;
    rbw.enable = lib.mkDefault true;
  };

  # Hyprland-specific QT theming
  qt.enable = true;
  qt.platformTheme.name = "adwaita";
  qt.style.name = "adwaita-dark";

  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "adwaita-dark";
  };

  services.udiskie.enable = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.mkDefault {
      "text/plain" = ["neovide.desktop"];
      "application/pdf" = ["org.pwmt.zathura-pdf-mupdf.desktop"];
      # Image formats
      "image/jpeg" = ["imv.desktop"];
      "image/jpg" = ["imv.desktop"];
      "image/png" = ["imv.desktop"];
      "image/gif" = ["imv.desktop"];
      "image/webp" = ["imv.desktop"];
      "image/bmp" = ["imv.desktop"];
      "image/svg+xml" = ["imv.desktop"];
      "image/tiff" = ["imv.desktop"];
      # Video formats
      "video/mp4" = ["mpv.desktop"];
      "video/webm" = ["mpv.desktop"];
      "video/x-matroska" = ["mpv.desktop"];
      "video/quicktime" = ["mpv.desktop"];
      "video/x-msvideo" = ["mpv.desktop"];
      # File management
      "inode/directory" = ["thunar.desktop"];
      "application/x-directory" = ["thunar.desktop"];
      # Web browser
      "text/html" = ["vivaldi-stable.desktop"];
      "x-scheme-handler/http" = ["vivaldi-stable.desktop"];
      "x-scheme-handler/https" = ["vivaldi-stable.desktop"];
      # Office documents - OnlyOffice
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = ["onlyoffice-desktopeditors.desktop"];
      "application/msword" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.ms-excel" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.ms-powerpoint" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.oasis.opendocument.text" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.oasis.opendocument.spreadsheet" = ["onlyoffice-desktopeditors.desktop"];
      "application/vnd.oasis.opendocument.presentation" = ["onlyoffice-desktopeditors.desktop"];
      # Archive files
      "application/zip" = ["thunar.desktop"];
      "application/x-rar" = ["thunar.desktop"];
      "application/x-tar" = ["thunar.desktop"];
      "application/x-7z-compressed" = ["thunar.desktop"];
      "application/gzip" = ["thunar.desktop"];
    };
  };

  # Mako for Wayland notifications (Hyprland)
  services.mako = {
    enable = true;
    settings = {
      border-radius = 5;
      border-size = 2;
      default-timeout = 10000;
      layer = "overlay";
    };
  };

  # Hyprland-specific packages
  home.packages = with pkgs; [
    signal-desktop
    youtube-music
    rofi-bluetooth
    feh
    polkit
    lxsession
    pulsemixer
    pavucontrol  # Keep for waybar widget integration
    easyeffects  # Superior audio control app (but conflicts with waybar volume control)
    adwaita-qt
    pcmanfm
    xfce.thunar
  ];
}
