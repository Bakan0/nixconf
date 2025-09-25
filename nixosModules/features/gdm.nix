{ pkgs, lib, config, ... }:
let
  cfg = config.myNixOS.gdm;

  # Copy wallpaper to Nix store so GDM can access it
  wallpaper = pkgs.copyPathToStore ../../homeManagerModules/features/stylix/atomic-terracotta-canyon.jpeg;

in {
  options.myNixOS.gdm = {
    preferExternalMonitor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prefer external monitor over laptop screen at login";
    };
    externalOutput = lib.mkOption {
      type = lib.types.str;
      default = "DP-1";
      description = "Name of external display output (DP-1, HDMI-1, etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable GDM as the display manager
    services.xserver.enable = true;
    services.displayManager.gdm = {
      enable = true;
      wayland = true;  # Enable Wayland support for GDM
    };

    # Configure fonts and packages for GDM
    environment.systemPackages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      gdm-settings  # GUI tool for checking GDM settings
      bibata-cursors  # Cursor theme
    ];

    # Enable dconf
    programs.dconf.enable = true;

    # GDM background: CSS overlay (requires gdm-settings to activate)
    # Running gdm-settings GUI was the catalyst that made CSS method work
    nixpkgs.overlays = [
      (self: super: {
        gnome-shell = super.gnome-shell.overrideAttrs (old: {
          patches = (old.patches or []) ++ [
            (pkgs.writeText "gdm-bg.patch" ''
              --- a/data/theme/gnome-shell-sass/widgets/_login-lock.scss
              +++ b/data/theme/gnome-shell-sass/widgets/_login-lock.scss
              @@ -15,4 +15,6 @@
               .login-dialog {
                 background-color: $_gdm_bg;
              +  background-image: url('file://${wallpaper}');
              +  background-size: cover;
               }
            '')
          ];
        });
      })
    ];

    # Configure GDM interface settings via dconf
    # (gdm-settings set background URI to same wallpaper)
    programs.dconf.profiles.gdm.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          gtk-theme = "Adwaita-dark";
          icon-theme = "Adwaita";
          cursor-theme = "Bibata-Modern-Amber";
          cursor-size = lib.gvariant.mkInt32 24;
          font-name = "JetBrainsMono Nerd Font 11";
          monospace-font-name = "JetBrainsMono Nerd Font Mono 11";
          clock-show-seconds = true;
          clock-show-weekday = true;
          clock-format = "24h";
          enable-animations = true;
        };

        "org/gnome/desktop/peripherals/mouse" = {
          accel-profile = "flat";
        };

        "org/gnome/login-screen" = {
          banner-message-enable = true;
          banner-message-text = "A wise man can learn more from a foolish question than a fool can learn from a wise answer.";
        };

        # GDM theming activation - gdm-settings sets this flag in dconf to enable CSS overlay
        "org/nixos/gdm-theming" = {
          initial-warning = false;  # Magic flag that activates gnome-shell custom theming
        };

        # Background scaling - override gdm-settings 'zoom' setting
        # Options: 'none', 'wallpaper', 'centered', 'scaled', 'stretched', 'zoom', 'spanned'
        "org/gnome/desktop/background" = {
          picture-options = "centered";  # Show image at natural size, centered
        };
      };
    }];

    # Note: External monitor preferences need to be configured through GNOME settings after login
    # GDM doesn't support display configuration scripts like SDDM
    # For proper theming, you'll need to use GNOME settings or gdm-settings after installation
  };
}
