{
  pkgs,
  lib,
  ...
}: {
  # GNOME-compatible desktop bundle
  # Includes general bundle but excludes Hyprland-specific configurations

  myHomeManager = {
    bundles.general.enable = lib.mkDefault true;

    # Essential desktop apps that work with GNOME
    zathura.enable = lib.mkDefault true;
    kitty.enable = lib.mkDefault true;
    imv.enable = lib.mkDefault false;
  };

  # GNOME-friendly QT theming (let GNOME handle it)
  qt.enable = true;
  qt.platformTheme.name = "gnome";


  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.mkDefault {
      "text/plain" = ["org.gnome.TextEditor.desktop"];
      "application/pdf" = ["org.pwmt.zathura-pdf-mupdf.desktop"];
      # Image formats - use GNOME's image viewer
      "image/jpeg" = ["org.gnome.eog.desktop"];
      "image/jpg" = ["org.gnome.eog.desktop"];
      "image/png" = ["org.gnome.eog.desktop"];
      "image/gif" = ["org.gnome.eog.desktop"];
      "image/webp" = ["org.gnome.eog.desktop"];
      "image/bmp" = ["org.gnome.eog.desktop"];
      "image/svg+xml" = ["org.gnome.eog.desktop"];
      "image/tiff" = ["org.gnome.eog.desktop"];
      # Video formats - use GNOME Videos or mpv
      "video/mp4" = ["org.gnome.Totem.desktop"];
      "video/webm" = ["org.gnome.Totem.desktop"];
      "video/x-matroska" = ["org.gnome.Totem.desktop"];
      "video/quicktime" = ["org.gnome.Totem.desktop"];
      "video/x-msvideo" = ["org.gnome.Totem.desktop"];
      # File management - use Nautilus
      "inode/directory" = ["org.gnome.Nautilus.desktop"];
      "application/x-directory" = ["org.gnome.Nautilus.desktop"];
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
    };
  };

  # GNOME-compatible packages only
  home.packages = with pkgs; [
    # Core desktop tools that work well with GNOME
    libnotify

    # Media tools
    mpv
    zathura

    # Productivity
    onlyoffice-bin
    obsidian
    bitwarden-desktop

    # Other tools
    virt-manager
  ];

  myHomeManager.impermanence.cache.directories = [
    ".local/state/wireplumber"
  ];
}