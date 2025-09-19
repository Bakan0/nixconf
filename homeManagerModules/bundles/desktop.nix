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
    myHomeManager.foot.enable = lib.mkDefault true;
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
        "application/pdf" = ["zathura.desktop"];
        "image/*" = ["imv.desktop"];
        "video/png" = ["mpv.desktop"];
        "video/jpg" = ["mpv.desktop"];
        "video/*" = ["mpv.desktop"];
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

    # Make mimeapps.list writable for runtime browser changes (like VSCode settings)
    home.activation.mimeAppsWritable = lib.hm.dag.entryAfter ["linkGeneration"] ''
      configMimeApps="$HOME/.config/mimeapps.list"
      localMimeApps="$HOME/.local/share/applications/mimeapps.list"

      # Make config mimeapps.list writable if it's a symlink
      if [ -L "$configMimeApps" ]; then
        echo "Making mimeapps.list writable for runtime browser changes..."
        target=$(readlink "$configMimeApps")
        rm "$configMimeApps"
        cp "$target" "$configMimeApps"
        chmod 644 "$configMimeApps"
        echo "mimeapps.list is now writable. Changes will persist until next home-manager switch."
      fi

      # Make local mimeapps.list writable if it's a symlink
      if [ -L "$localMimeApps" ]; then
        target=$(readlink "$localMimeApps")
        rm "$localMimeApps"
        cp "$target" "$localMimeApps"
        chmod 644 "$localMimeApps"
      fi
    '';
  };
}
