{ config, lib, pkgs, ... }:
{
  services.displayManager.lemurs = {
    enable = true;
    settings = {
      # Optional: Set which TTY to use (default is 2)
      tty = lib.mkDefault 2;

      # Style settings - using terracotta-like colors
      # Note: These are example settings, adjust based on actual Lemurs config options
      # You may need to check Lemurs documentation for exact theme options
    };
  };

  # Ensure seat management is available
  services.seatd.enable = true;
}