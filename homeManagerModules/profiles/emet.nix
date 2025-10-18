{ config, pkgs, lib, myLib, ... }:

{
  # Inherit common settings for all users
  myHomeManager.profiles.common.enable = true;

  # Enable emet's preferred bundles by default (can be overridden per host)
  myHomeManager = {

    bundles.desktop = {
      enable = lib.mkDefault true;
      hyprland.enable = lib.mkDefault false;  # Disabled by default - enable per host if needed
      gnome = {
        enable = lib.mkDefault true;
        tiling.enable = lib.mkDefault true;  # Hyprland-like tiling for GNOME
      };
    };
    bundles.graphics-performance.enable = lib.mkDefault true;
    bundles.databender.enable = lib.mkDefault true;
    bundles.xfer-scripts.enable = lib.mkDefault true;

    # Features
    zsh.enable = false;   # Legacy vimjoyer code - not used
    firefox.enable = lib.mkDefault true;
    # hyprland and waybar now handled by desktop-hyprland bundle
    microsoft.enable = lib.mkDefault true;  # Default for emet - override per host if needed
    nextcloud-client = {
      enable = lib.mkDefault true;
      symlinkUserDirs = lib.mkDefault true;  # OneDrive-style integration
    };
    
    # Stylix theme preference for emet
    stylix = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "atomic-terracotta";
      iconTheme = lib.mkDefault "numix";  # Professional with orange accents
    };

  };

  # Auto-start btop when desktop starts (Hyprland)
  myHomeManager.startupScript = ''
    ${pkgs.kitty}/bin/kitty --title "System Monitor - btop" ${pkgs.btop}/bin/btop &
  '';

  # Auto-start btop when desktop starts (GNOME and other XDG-compliant desktops)
  # Only enable XDG autostart when GNOME is enabled to avoid duplicate starts with Hyprland
  xdg.configFile."autostart/btop.desktop" = lib.mkIf config.myHomeManager.bundles.desktop.gnome.enable {
    text = ''
      [Desktop Entry]
      Type=Application
      Name=System Monitor (btop)
      Exec=${pkgs.kitty}/bin/kitty --title "System Monitor - btop" ${pkgs.btop}/bin/btop
      Hidden=false
      NoDisplay=false
      X-GNOME-Autostart-enabled=true
    '';
  };
}
