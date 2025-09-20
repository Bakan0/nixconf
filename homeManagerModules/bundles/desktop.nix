{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: {
  options = {
    myHomeManager.startupScript = lib.mkOption {
      default = "";
      description = ''
        Startup script
      '';
    };
  };

  config = {
    myHomeManager.zathura.enable = lib.mkDefault true;
    myHomeManager.rofi.enable = lib.mkDefault true;
    myHomeManager.kitty.enable = lib.mkDefault true;
    myHomeManager.xremap.enable = lib.mkDefault false;
    myHomeManager.imv.enable = lib.mkDefault false;

    home.file = {
      ".local/share/rofi/rofi-bluetooth".source = "${pkgs.rofi-bluetooth}";
    };

    qt.enable = true;
    qt.platformTheme.name = "gtk";
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
        # Image formats - explicit types needed, wildcards don't work
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
        "video/png" = ["mpv.desktop"];
        "video/jpg" = ["mpv.desktop"];
        "inode/directory" = ["thunar.desktop"];
        "application/x-directory" = ["thunar.desktop"];
        "application/x-iso9660-image" = ["thunar.desktop"];
        "application/x-cd-image" = ["thunar.desktop"];
        "text/html" = ["vivaldi-stable.desktop"];
        "x-scheme-handler/http" = ["vivaldi-stable.desktop"];
        "x-scheme-handler/https" = ["vivaldi-stable.desktop"];
        # Office documents - OnlyOffice
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = ["onlyoffice-desktopeditors.desktop"]; # docx
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = ["onlyoffice-desktopeditors.desktop"]; # xlsx
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" = ["onlyoffice-desktopeditors.desktop"]; # pptx
        "application/msword" = ["onlyoffice-desktopeditors.desktop"]; # doc
        "application/vnd.ms-excel" = ["onlyoffice-desktopeditors.desktop"]; # xls
        "application/vnd.ms-powerpoint" = ["onlyoffice-desktopeditors.desktop"]; # ppt
        "application/vnd.oasis.opendocument.text" = ["onlyoffice-desktopeditors.desktop"]; # odt
        "application/vnd.oasis.opendocument.spreadsheet" = ["onlyoffice-desktopeditors.desktop"]; # ods
        "application/vnd.oasis.opendocument.presentation" = ["onlyoffice-desktopeditors.desktop"]; # odp
        # Archive files - file manager (thunar can handle archives)
        "application/zip" = ["thunar.desktop"];
        "application/x-rar" = ["thunar.desktop"];
        "application/x-tar" = ["thunar.desktop"];
        "application/x-7z-compressed" = ["thunar.desktop"];
        "application/gzip" = ["thunar.desktop"];
      };
    };

  services.mako = {
    enable = true;
    settings = {
      border-radius = 5;
      border-size = 2;
      default-timeout = 10000;
      layer = "overlay";
    };
  };

    home.packages = with pkgs; [
      feh
      noisetorch
      polkit
      lxsession
      pulsemixer
      pavucontrol
      adwaita-qt
      pcmanfm
      xfce.thunar
      libnotify

      pywal
      neovide
      ripdrag
      mpv
      sxiv
      zathura
      foot
      cm_unicode

      virt-manager

      kitty

      bitwarden-desktop
      onlyoffice-bin
      obsidian
      easyeffects
      gegl
    ];

    myHomeManager.impermanence.cache.directories = [
      ".local/state/wireplumber"
    ];

    # Fix mimeapps.list handling - ALWAYS work regardless of file state
    home.activation.mimeAppsWritable = lib.hm.dag.entryBefore ["linkGeneration"] ''
      configMimeApps="$HOME/.config/mimeapps.list"
      localMimeApps="$HOME/.local/share/applications/mimeapps.list"

      # Remove existing files before linkGeneration to avoid conflicts
      if [ -e "$configMimeApps" ] && [ ! -L "$configMimeApps" ]; then
        echo "Removing existing mimeapps.list to prevent conflicts..."
        rm -f "$configMimeApps"
      fi

      if [ -e "$localMimeApps" ] && [ ! -L "$localMimeApps" ]; then
        echo "Removing existing local mimeapps.list to prevent conflicts..."
        rm -f "$localMimeApps"
      fi
    '';

    home.activation.mimeAppsWritablePost = lib.hm.dag.entryAfter ["linkGeneration"] ''
      configMimeApps="$HOME/.config/mimeapps.list"
      localMimeApps="$HOME/.local/share/applications/mimeapps.list"

      # Now make them writable after linkGeneration created them
      if [ -L "$configMimeApps" ]; then
        echo "Making mimeapps.list writable..."
        target=$(readlink "$configMimeApps")
        rm "$configMimeApps"
        cp "$target" "$configMimeApps"
        chmod 644 "$configMimeApps"
      fi

      if [ -L "$localMimeApps" ]; then
        target=$(readlink "$localMimeApps")
        rm "$localMimeApps"
        cp "$target" "$localMimeApps"
        chmod 644 "$localMimeApps"
      fi
    '';
  };
}
