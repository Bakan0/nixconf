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
    myHomeManager.alacritty.enable = lib.mkDefault true;
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
        # Browser associations removed - managed manually via xdg-settings
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

      wezterm
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
  };
}
