{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.myHomeManager.stylix;

  # Theme definitions
  themes = {
    atomic-terracotta = {
      base00 = "1a1a1a"; # Dark background (charcoal/ash)
      base01 = "2d2d2d"; # Lighter background
      base02 = "3d3d3d"; # Selection background
      base03 = "4a4a4a"; # Comments/disabled
      base04 = "b8b8b8"; # Dark foreground
      base05 = "d4d4d4"; # Default foreground
      base06 = "e8e8e8"; # Light foreground
      base07 = "f5f5f5"; # Lightest foreground
      base08 = "b7410e"; # Rust red-orange (deeper, earthier)
      base09 = "a0522d"; # Sienna - the "crimson of orange"
      base0A = "cd853f"; # Peru/golden rod - rich but not peachy
      base0B = "74a478"; # Green (success)
      base0C = "4d9494"; # Cyan/teal (info)
      base0D = "6ba6cd"; # Blue (links/info)
      base0E = "a47996"; # Purple/magenta
      base0F = "8b4513"; # Saddle brown - deep burnt orange
    };

    gruvbox = {
      base00 = "242424"; # ----
      base01 = "3c3836"; # ---
      base02 = "504945"; # --
      base03 = "665c54"; # -
      base04 = "bdae93"; # +
      base05 = "d5c4a1"; # ++
      base06 = "ebdbb2"; # +++
      base07 = "fbf1c7"; # ++++
      base08 = "fb4934"; # red
      base09 = "fe8019"; # orange
      base0A = "fabd2f"; # yellow
      base0B = "b8bb26"; # green
      base0C = "8ec07c"; # aqua/cyan
      base0D = "7daea3"; # blue
      base0E = "e089a1"; # purple
      base0F = "f28534"; # brown
    };

    crimson-noir = {
      base00 = "0a0a0a"; # Pure black background
      base01 = "1a1a1a"; # Slightly lighter black
      base02 = "2a2a2a"; # Dark gray for selection
      base03 = "404040"; # Medium gray for comments
      base04 = "a0a0a0"; # Light gray
      base05 = "e0e0e0"; # Off-white for main text
      base06 = "f0f0f0"; # Bright white
      base07 = "ffffff"; # Pure white for emphasis
      base08 = "dc143c"; # Crimson red (primary accent)
      base09 = "ff4444"; # Bright red
      base0A = "ff6666"; # Light red/pink
      base0B = "cc4444"; # Dark red for success
      base0C = "b04040"; # Deep red for info
      base0D = "a03030"; # Wine red for links
      base0E = "ff1744"; # Vivid red for purple replacement
      base0F = "8b0000"; # Dark red for brown replacement
    };
  };
  
  # Theme wallpapers
  wallpapers = {
    atomic-terracotta = ./atomic-terracotta-canyon.jpeg;
    gruvbox = ./gruvbox-mountain-village.png;
    crimson-noir = ./butterfly-red-jellyfish.jpeg;
  };
in {
  options.myHomeManager.stylix = {
    theme = mkOption {
      type = types.enum [ "atomic-terracotta" "gruvbox" "crimson-noir" ];
      default = "atomic-terracotta";
      description = "The stylix theme to use";
    };
  };

  config = {
    stylix = {
      base16Scheme = themes.${cfg.theme};
      image = wallpapers.${cfg.theme};
      
      fonts = {
        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font Mono";
        };
        sansSerif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Sans";
        };
        serif = {
          package = pkgs.dejavu_fonts;
          name = "DejaVu Serif";
        };
        
        sizes = {
          applications = 12;
          terminal = 15;
          desktop = 10;
          popups = 10;
        };
      };
      
      autoEnable = true;
      
      # Explicit targets for applications that need them
      targets = {
        foot.enable = true;
        kitty.enable = true;
        waybar.enable = true;
        rofi.enable = true;
        gtk.enable = true;
        hyprland.enable = true;
        gnome.enable = true;
        firefox.enable = true;
        vscode.enable = true;
      };
      
      polarity = "dark";
    };

    # Configure icon theme - candy-icons perfect for terracotta with sweet gradients
    gtk = {
      iconTheme = {
        name = "candy-icons";  # Sweet gradients complement terracotta perfectly
        package = pkgs.candy-icons;
      };
    };

    # Force GNOME to use stylix wallpaper and theming
    dconf.settings = {
      "org/gnome/desktop/background" = {
        picture-uri = "file://${config.stylix.image}";
        picture-uri-dark = "file://${config.stylix.image}";
        picture-options = "zoom";
      };
      "org/gnome/desktop/screensaver" = {
        picture-uri = "file://${config.stylix.image}";
        picture-options = "zoom";
      };
      "org/gnome/desktop/interface" = {
        color-scheme = if config.stylix.polarity == "dark" then "prefer-dark" else "prefer-light";
      };
    };
  };
}
