{
  pkgs,
  lib,
  ...
}: {
  stylix = {
    targets.waybar.enable = true;
    targets.rofi.enable = true;
    targets.kde.enable = false;
    targets.mako.enable = false;
  };

  # Configure icon theme - candy-icons perfect for terracotta with sweet gradients
  gtk = {
    iconTheme = {
      name = "candy-icons";  # Sweet gradients complement terracotta perfectly
      package = pkgs.candy-icons;
    };
  };
}
