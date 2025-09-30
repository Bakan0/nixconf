{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myHomeManager.nextcloud-client;
in {
  options.myHomeManager.nextcloud-client = {
    symlinkUserDirs = mkOption {
      type = types.bool;
      default = true;
      description = "Create symlinks from standard user directories to Nextcloud (OneDrive-style)";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nextcloud-client
      (writeShellScriptBin "nextcloud-setup" ''
        set -euo pipefail
        echo "🔗 Nextcloud Client Setup"
        echo "========================="
        echo ""
        echo "1. First run: nextcloud (GUI will open for account setup)"
        echo "2. Configure sync folder to: $HOME/nc"
        echo "3. After setup: systemctl --user enable --now nextcloud-client"
        echo ""
        echo "Starting Nextcloud client GUI..."
        exec ${pkgs.nextcloud-client}/bin/nextcloud
      '')
    ];

    # Auto-create the Nextcloud directory
    home.file."nc/.keep".text = "";
    
    # Create systemd service for Nextcloud client
    systemd.user.services.nextcloud-client = {
      Unit = {
        Description = "Nextcloud desktop sync client";
        After = [ "graphical-session.target" ];
        Wants = [ "graphical-session.target" ];
        # Only start if config exists (after initial setup)
        ConditionPathExists = "%h/.config/Nextcloud/nextcloud.cfg";
        # Only start when display is available
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.nextcloud-client}/bin/nextcloud --background";
        Restart = "on-failure";
        RestartSec = "10s";
        # Let Qt detect the best platform automatically
      };
      
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Ensure virtual files mode is set correctly (enable on-demand download)
    home.activation.nextcloudVfsMode = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -f "$HOME/.config/Nextcloud/nextcloud.cfg" ]; then
        if grep -q "virtualFilesMode=wincfapi" "$HOME/.config/Nextcloud/nextcloud.cfg"; then
          echo "Fixing Nextcloud VFS mode: wincfapi -> suffix (Linux)"
          $DRY_RUN_CMD sed -i 's/virtualFilesMode=wincfapi/virtualFilesMode=suffix/' "$HOME/.config/Nextcloud/nextcloud.cfg"
        elif grep -q "virtualFilesMode=off" "$HOME/.config/Nextcloud/nextcloud.cfg"; then
          echo "Enabling Nextcloud VFS mode: off -> suffix (on-demand download)"
          $DRY_RUN_CMD sed -i 's/virtualFilesMode=off/virtualFilesMode=suffix/' "$HOME/.config/Nextcloud/nextcloud.cfg"
        fi
      fi
    '';

    # Ensure the ~/nc directory and subdirectories exist
    home.activation.nextcloudSetup = lib.hm.dag.entryAfter ["writeBoundary"] (''
      $DRY_RUN_CMD mkdir -p "$HOME/nc"
      $DRY_RUN_CMD chmod 755 "$HOME/nc"
      
      # Create standard Nextcloud folders
      $DRY_RUN_CMD mkdir -p "$HOME/nc/Documents"
      $DRY_RUN_CMD mkdir -p "$HOME/nc/Downloads" 
      $DRY_RUN_CMD mkdir -p "$HOME/nc/Pictures"
      $DRY_RUN_CMD mkdir -p "$HOME/nc/Music"
      $DRY_RUN_CMD mkdir -p "$HOME/nc/Videos"
      $DRY_RUN_CMD mkdir -p "$HOME/nc/Desktop"
    '' + optionalString cfg.symlinkUserDirs ''
      
      # OneDrive-style: Merge and symlink user directories
      # Handle existing files by moving them to Nextcloud first
      if [ -d "$HOME/Documents" ] && [ ! -L "$HOME/Documents" ]; then
        echo "Merging existing ~/Documents with Nextcloud..."
        $DRY_RUN_CMD cp -r "$HOME/Documents"/* "$HOME/nc/Documents/" 2>/dev/null || true
        $DRY_RUN_CMD cp -r "$HOME/Documents"/.[^.]* "$HOME/nc/Documents/" 2>/dev/null || true
        $DRY_RUN_CMD rm -rf "$HOME/Documents"
      fi
      $DRY_RUN_CMD ln -sf "$HOME/nc/Documents" "$HOME/Documents"
      
      if [ -d "$HOME/Pictures" ] && [ ! -L "$HOME/Pictures" ]; then
        echo "Merging existing ~/Pictures with Nextcloud..."
        $DRY_RUN_CMD cp -r "$HOME/Pictures"/* "$HOME/nc/Pictures/" 2>/dev/null || true
        $DRY_RUN_CMD cp -r "$HOME/Pictures"/.[^.]* "$HOME/nc/Pictures/" 2>/dev/null || true
        $DRY_RUN_CMD rm -rf "$HOME/Pictures"
      fi
      $DRY_RUN_CMD ln -sf "$HOME/nc/Pictures" "$HOME/Pictures"
      
      if [ -d "$HOME/Music" ] && [ ! -L "$HOME/Music" ]; then
        echo "Merging existing ~/Music with Nextcloud..."
        $DRY_RUN_CMD cp -r "$HOME/Music"/* "$HOME/nc/Music/" 2>/dev/null || true
        $DRY_RUN_CMD cp -r "$HOME/Music"/.[^.]* "$HOME/nc/Music/" 2>/dev/null || true
        $DRY_RUN_CMD rm -rf "$HOME/Music"
      fi
      $DRY_RUN_CMD ln -sf "$HOME/nc/Music" "$HOME/Music"
      
      if [ -d "$HOME/Videos" ] && [ ! -L "$HOME/Videos" ]; then
        echo "Merging existing ~/Videos with Nextcloud..."
        $DRY_RUN_CMD cp -r "$HOME/Videos"/* "$HOME/nc/Videos/" 2>/dev/null || true
        $DRY_RUN_CMD cp -r "$HOME/Videos"/.[^.]* "$HOME/nc/Videos/" 2>/dev/null || true
        $DRY_RUN_CMD rm -rf "$HOME/Videos"
      fi
      $DRY_RUN_CMD ln -sf "$HOME/nc/Videos" "$HOME/Videos"
      
      # Note: Downloads stays local (too much temp stuff), Desktop optional
      echo "Nextcloud OneDrive-style integration complete!"
      echo "~/Documents -> ~/nc/Documents"
      echo "~/Pictures -> ~/nc/Pictures" 
      echo "~/Music -> ~/nc/Music"
      echo "~/Videos -> ~/nc/Videos"
    '');
  };
}