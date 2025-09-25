{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: let
  cfg = config.myHomeManager.bundles.desktop;
in {
  options = {
    myHomeManager.startupScript = lib.mkOption {
      default = "";
      description = ''
        Startup script
      '';
    };

    myHomeManager.bundles.desktop = {
      hyprland.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Hyprland desktop customizations";
      };

      gnome = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable GNOME desktop customizations";
        };
        tiling.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Hyprland-like tiling mode for GNOME";
        };
      };
    };
  };

  config = lib.mkMerge [
    # Base desktop configuration (always applied when bundle is enabled)
    {
      myHomeManager.bundles.general.enable = lib.mkDefault true;

      # Basic desktop apps that work across all DEs/WMs
      myHomeManager.zathura.enable = lib.mkDefault true;
      myHomeManager.kitty.enable = lib.mkDefault true;
      myHomeManager.imv.enable = lib.mkDefault false;
      myHomeManager.gimp.enable = lib.mkDefault true;

      home.packages = with pkgs; [
        # Core desktop tools that work across DEs/WMs
        noisetorch
        libnotify
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
        gegl  # GIMP's image processing backend
        # Communication apps for all DEs
        signal-desktop
        youtube-music
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
    }

    # Hyprland-specific configuration
    (lib.mkIf cfg.hyprland.enable {
      # Hyprland and related components
      myHomeManager = {
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
    })

    # GNOME-specific configuration
    (lib.mkIf cfg.gnome.enable {
      # Enable GNOME customizations
      myHomeManager.gnome.enable = lib.mkDefault true;

      # Pass through the tiling option to the GNOME feature
      myHomeManager.gnome.tiling.enable = lib.mkDefault cfg.gnome.tiling.enable;

      # Essential desktop apps that work with GNOME
      myHomeManager.zathura.enable = lib.mkDefault true;
      myHomeManager.kitty.enable = lib.mkDefault true;
      myHomeManager.imv.enable = lib.mkDefault false;
    })

    # Universal MIME defaults using Hyprland apps (they work well in GNOME)
    # Individual DEs can override these with their preferred applications
    {
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          # Universal browser (never needs overriding)
          "text/html" = lib.mkDefault "vivaldi-stable.desktop";
          "x-scheme-handler/http" = lib.mkDefault "vivaldi-stable.desktop";
          "x-scheme-handler/https" = lib.mkDefault "vivaldi-stable.desktop";

          # Hyprland defaults (GNOME can override)
          "text/plain" = lib.mkDefault "neovide.desktop";
          "inode/directory" = lib.mkDefault "thunar.desktop";
          "application/x-directory" = lib.mkDefault "thunar.desktop";
          "application/pdf" = lib.mkDefault "org.pwmt.zathura-pdf-mupdf.desktop";

          # Image formats
          "image/jpeg" = lib.mkDefault "imv.desktop";
          "image/jpg" = lib.mkDefault "imv.desktop";
          "image/png" = lib.mkDefault "imv.desktop";
          "image/gif" = lib.mkDefault "imv.desktop";
          "image/webp" = lib.mkDefault "imv.desktop";
          "image/bmp" = lib.mkDefault "imv.desktop";
          "image/svg+xml" = lib.mkDefault "imv.desktop";
          "image/tiff" = lib.mkDefault "imv.desktop";

          # Video formats
          "video/mp4" = lib.mkDefault "mpv.desktop";
          "video/webm" = lib.mkDefault "mpv.desktop";
          "video/x-matroska" = lib.mkDefault "mpv.desktop";
          "video/quicktime" = lib.mkDefault "mpv.desktop";
          "video/x-msvideo" = lib.mkDefault "mpv.desktop";

          # Universal office apps (work everywhere)
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.openxmlformats-officedocument.presentationml.presentation" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/msword" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.ms-excel" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.ms-powerpoint" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.oasis.opendocument.text" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.oasis.opendocument.spreadsheet" = lib.mkDefault "onlyoffice-desktopeditors.desktop";
          "application/vnd.oasis.opendocument.presentation" = lib.mkDefault "onlyoffice-desktopeditors.desktop";

          # Archive files
          "application/zip" = lib.mkDefault "thunar.desktop";
          "application/x-rar" = lib.mkDefault "thunar.desktop";
          "application/x-tar" = lib.mkDefault "thunar.desktop";
          "application/x-7z-compressed" = lib.mkDefault "thunar.desktop";
          "application/gzip" = lib.mkDefault "thunar.desktop";
        };
      };
    }
  ];
}