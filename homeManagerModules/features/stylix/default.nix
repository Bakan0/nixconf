{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  
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
  };
  
  # Theme wallpapers
  wallpapers = {
    atomic-terracotta = ./atomic-terracotta-canyon.jpeg;
    gruvbox = ./gruvbox-mountain-village.png;
  };
in {
  config = {
    stylix = {
      base16Scheme = themes.atomic-terracotta;
      image = wallpapers.atomic-terracotta;
      
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
        kitty.enable = true;
        waybar.enable = true;
        rofi.enable = true;
        gtk.enable = true;
        hyprland.enable = true;
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
  };
}
