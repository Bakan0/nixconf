{
  pkgs,
  config,
  inputs,
  lib,
  ...
}: {
  options = {
    myHomeManager.startupScript = lib.mkOption {
      default = "";
      description = ''
        Startup script
      '';
    };
  };

  config = {

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
  };
}
