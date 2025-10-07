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
        echo "1. Run: nextcloud (GUI will open for account setup)"
        echo "2. Configure sync folder to: $HOME/nc"
        echo "3. Client will auto-start on login (XDG autostart)"
        echo "4. VFS (virtual files) will be auto-enabled by NixOS config"
        echo ""
        echo "Starting Nextcloud client GUI..."
        exec ${pkgs.nextcloud-client}/bin/nextcloud
      '')
    ];

    # Auto-create the Nextcloud directory
    home.file."nc/.keep".text = "";
    
    # XDG autostart desktop entry - works across all DEs (GNOME, Hyprland, etc)
    xdg.configFile."autostart/nextcloud-client.desktop".text = ''
      [Desktop Entry]
      Name=Nextcloud
      GenericName=File Synchronizer
      Exec=${pkgs.nextcloud-client}/bin/nextcloud --background
      Terminal=false
      Icon=Nextcloud
      Categories=Network;
      Type=Application
      StartupNotify=false
      X-GNOME-Autostart-enabled=true
      X-GNOME-Autostart-Delay=3
    '';

    # Systemd path unit to watch for config changes and enforce VFS
    systemd.user.paths.nextcloud-vfs-enforcer = {
      Unit = {
        Description = "Watch Nextcloud config for VFS changes";
      };
      Path = {
        PathChanged = "%h/.config/Nextcloud/nextcloud.cfg";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Service that enforces VFS when config changes
    systemd.user.services.nextcloud-vfs-enforcer = {
      Unit = {
        Description = "Enforce Nextcloud VFS settings";
      };
      Service = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "nextcloud-vfs-enforcer" ''
          NC_CFG="$HOME/.config/Nextcloud/nextcloud.cfg"
          if [ -f "$NC_CFG" ]; then
            # Fix isVfsEnabled if disabled
            if ${pkgs.gnugrep}/bin/grep -q "^isVfsEnabled=false" "$NC_CFG"; then
              ${pkgs.gnused}/bin/sed -i 's/^isVfsEnabled=false/isVfsEnabled=true/' "$NC_CFG"
              echo "Nextcloud VFS auto-fixed: isVfsEnabled=false -> true"
            fi

            # Remove orphaned Folders entries (keep only FoldersWithPlaceholders)
            ${pkgs.gnused}/bin/sed -i '/^[0-9]\+\\Folders\\[0-9]\+\\virtualFilesMode=/d' "$NC_CFG"
          fi
        '';
      };
    };

    # Remove old GNOME-created autostart entry (let NixOS manage it)
    home.activation.removeOldNextcloudAutostart = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      if [ -f "$HOME/.config/autostart/Nextcloud.desktop" ] && [ ! -L "$HOME/.config/autostart/Nextcloud.desktop" ]; then
        echo "Removing old Nextcloud autostart entry (NixOS will manage it)"
        $DRY_RUN_CMD rm -f "$HOME/.config/autostart/Nextcloud.desktop"
      fi
    '';

    # Ensure virtual files mode is enabled (on-demand download)
    # VFS requires both global flag AND per-account folder configuration
    home.activation.nextcloudVfsMode = lib.hm.dag.entryAfter ["writeBoundary"] ''
      NC_CFG="$HOME/.config/Nextcloud/nextcloud.cfg"
      if [ -f "$NC_CFG" ]; then
        CHANGED=false

        # 1. Enable VFS globally if disabled
        if grep -q "^isVfsEnabled=false" "$NC_CFG"; then
          echo "Enabling Nextcloud VFS globally: isVfsEnabled=false -> true"
          $DRY_RUN_CMD sed -i 's/^isVfsEnabled=false/isVfsEnabled=true/' "$NC_CFG"
          CHANGED=true
        elif ! grep -q "^isVfsEnabled=" "$NC_CFG"; then
          echo "Adding Nextcloud VFS global setting: isVfsEnabled=true"
          $DRY_RUN_CMD sed -i '/^\[General\]/a isVfsEnabled=true' "$NC_CFG"
          CHANGED=true
        fi

        # 2. Add virtualFilesMode to each account if missing (Nextcloud stores per-account)
        # Format: 0\Folders\1\virtualFilesMode=suffix (under [Accounts] section)
        ACCOUNT_COUNT=$(grep -c "^[0-9]\+\\\\dav_user=" "$NC_CFG" || echo "0")
        if [ "$ACCOUNT_COUNT" -gt 0 ]; then
          for i in $(seq 0 $((ACCOUNT_COUNT - 1))); do
            # Check if this account already has virtualFilesMode configured
            if ! grep -q "^$i\\\\Folders\\\\1\\\\virtualFilesMode=" "$NC_CFG"; then
              echo "Enabling VFS for Nextcloud account $i (suffix mode)"
              # Insert after the account's version line (last line of account config)
              $DRY_RUN_CMD sed -i "/^$i\\\\version=/a $i\\\\Folders\\\\1\\\\virtualFilesMode=suffix" "$NC_CFG"
              CHANGED=true
            fi
          done
        fi

        # 3. Fix incorrect VFS modes (Windows mode on Linux)
        if grep -q "virtualFilesMode=wincfapi" "$NC_CFG"; then
          echo "Fixing Nextcloud VFS mode: wincfapi -> suffix (Linux)"
          $DRY_RUN_CMD sed -i 's/virtualFilesMode=wincfapi/virtualFilesMode=suffix/' "$NC_CFG"
          CHANGED=true
        fi
        if grep -q "virtualFilesMode=off" "$NC_CFG"; then
          echo "Fixing Nextcloud VFS mode: off -> suffix"
          $DRY_RUN_CMD sed -i 's/virtualFilesMode=off/virtualFilesMode=suffix/' "$NC_CFG"
          CHANGED=true
        fi

        if [ "$CHANGED" = true ]; then
          echo "⚠️  Nextcloud VFS config updated - restart Nextcloud client to apply"
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