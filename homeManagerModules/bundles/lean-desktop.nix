{
  pkgs,
  lib,
  ...
}: {
  # Lean desktop bundle - forcefully strips heavy packages from profiles
  # Use mkOverride to override lib.mkDefault from profiles (like profiles.emet)
  # This is an EXCEPTION to the "no mkForce/mkOverride" rule - needed for lean systems

  myHomeManager = {
    # Strip heavy bundles (override profile defaults)
    microsoft.enable = lib.mkOverride 900 false;
    firefox.enable = lib.mkOverride 900 false;
    chromium.enable = lib.mkOverride 900 false;
    nextcloud-client.enable = lib.mkOverride 900 false;
    bundles.graphics-performance.enable = lib.mkOverride 900 false;
    bundles.databender.enable = lib.mkOverride 900 false;
    vscode.enable = lib.mkOverride 900 false;
    bundles.xfer-scripts.enable = lib.mkOverride 900 false;
    claude-code-latest.enable = lib.mkDefault true;

    # Disable heavy desktop apps
    gimp.enable = lib.mkOverride 900 false;
    vesktop.enable = lib.mkOverride 900 false;
    nvim.enable = lib.mkOverride 900 false;
    imv.enable = lib.mkOverride 900 false;

    # Disable GNOME entirely
    gnome.enable = lib.mkOverride 900 false;
    bundles.desktop.gnome.enable = lib.mkOverride 900 false;

    # Prefer Hyprland over GNOME
    bundles.desktop.hyprland.enable = lib.mkOverride 900 true;
  };

  # Override hardcoded enables in feature modules
  programs.firefox.enable = lib.mkOverride 900 false;
  programs.chromium.enable = lib.mkOverride 900 false;

  # Lightweight desktop packages (override desktop bundle's optional packages)
  home.packages = lib.mkOverride 900 (with pkgs; [
    ripdrag
    mpv
    sxiv
    foot
    zathura
    cm_unicode
  ]);
}
