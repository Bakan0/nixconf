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
  
  # Import theme definitions
  themes = import ./themes.nix;
  
  # Theme-specific wallpapers
  wallpapers = {
    "atomic-terracotta" = ./atomic-terracotta-canyon.jpeg;
    "gruvbox" = ./gruvbox-mountain-village.png;
    # "butterfly-pastel" = ./butterfly-pastel-wallpaper.png; # TODO: Add when you find a good pastel wallpaper
  };
in {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  options.myNixOS.stylix = {
    theme = mkOption {
      type = types.enum [ "gruvbox" "atomic-terracotta" "butterfly-pastel" ];
      default = "atomic-terracotta";  # System default, can be overridden per-host
      description = "Which theme to use for Stylix";
    };
  };

  config = mkIf cfg.enable {
    stylix = {
      base16Scheme = themes.${cfg.theme};

    image = wallpapers.${cfg.theme} or ./gruvbox-mountain-village.png;

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
      enable = true;
    };
  };
}
