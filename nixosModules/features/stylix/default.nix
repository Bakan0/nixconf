{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: 
with lib;
let
  cfg = config.myNixOS.stylix;
  
  # Define available theme schemes
  themes = {
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
    
    terracotta-atomic = {
      base00 = "1a1a1a"; # Dark background (charcoal/ash)
      base01 = "2d2d2d"; # Lighter background
      base02 = "3d3d3d"; # Selection background  
      base03 = "4a4a4a"; # Comments/disabled
      base04 = "b8b8b8"; # Dark foreground
      base05 = "d4d4d4"; # Default foreground
      base06 = "e8e8e8"; # Light foreground
      base07 = "f5f5f5"; # Lightest foreground
      base08 = "d73027"; # Red (error/danger)
      base09 = "d73502"; # Orange/terracotta primary - main accent
      base0A = "f46d43"; # Yellow/warm orange - secondary
      base0B = "74a478"; # Green (success)
      base0C = "4d9494"; # Cyan/teal (info)
      base0D = "6ba6cd"; # Blue (links/info)
      base0E = "a47996"; # Purple/magenta
      base0F = "bf5c00"; # Brown/burnt orange - tertiary
    };
  };

  # Select wallpaper based on theme
  wallpapers = {
    gruvbox = ./gruvbox-mountain-village.png;
    terracotta-atomic = ./gruvbox-mountain-village.png; # TODO: create terracotta wallpaper
  };
in {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  options.myNixOS.stylix = {
    theme = mkOption {
      type = types.enum [ "gruvbox" "terracotta-atomic" ];
      default = "gruvbox";
      description = "Which theme to use for Stylix";
    };
  };

  config = mkIf cfg.enable {
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

    # cursor.name = "Banana-Gruvbox";
    # cursor.package = pkgs.bibata-cursors;

    # cursor.package = let
    #   banana = pkgs.stdenv.mkDerivation {
    #     name = "banana-cursor";

    #     src = builtins.fetchurl {
    #       url = "https://github.com/vimjoyer/banana-cursor-gruvbox/releases/download/4/Banana-Gruvbox.tar.gz";
    #       sha256 = "sha256-opGDdW7w2eAhwP/fuBES3qA6d7M8I/xhdXiTXoIoGzs=";
    #     };
    #     unpack = false;

    #     installPhase = ''
    #       mkdir -p $out/share/icons/Banana-Gruvbox
    #       tar -xvf $src -C $out/share/icons/Banana-Gruvbox
    #     '';
    #   };
    # in
    #   banana;

    targets = {
      chromium.enable = true;
      grub.enable = true;
      grub.useImage = true;
      gtk.enable = true;
      plymouth.enable = false;
    };
    polarity = "dark";
  # opacity.terminal = 1;
  # stylix.targets.nixos-icons.enable = true;

      autoEnable = true;
    };
  };
}
