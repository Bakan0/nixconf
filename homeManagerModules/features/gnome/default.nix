{
  pkgs,
  lib,
  config,
  ...
}: {
  # GNOME desktop environment customizations
  # These are Home Manager level customizations for GNOME users

  # Always import tiling.nix - it will only apply if both gnome and tiling are enabled
  imports = [ ./tiling.nix ];

  options.myHomeManager.gnome.tiling.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Hyprland-like tiling configuration for GNOME";
  };

  config = lib.mkIf config.myHomeManager.gnome.enable {
    # GNOME-friendly QT theming (let GNOME handle it)
    qt = {
      enable = true;
      platformTheme.name = "adwaita";
      style.name = "adwaita-dark";
    };

    # Core GNOME settings (apply regardless of tiling)
    dconf.settings = {
      # Clear GNOME keybindings that conflict with Pop Shell
      # These are set to empty to prevent interference with Pop Shell's vim navigation
      "org/gnome/desktop/wm/keybindings" = {
        # Clear any bindings that might conflict with Meta+vim keys
        switch-applications = [];
        switch-applications-backward = [];

        # Ensure nothing else is bound to our vim keys
        cycle-windows = [];
        cycle-windows-backward = [];

        # Clear any potential conflicts with specific Pop Shell keys
        minimize = [];  # Often bound to Super+h (hide)
        maximize = [];
        unmaximize = [];

        # Ensure directional movement keys are free
        move-to-monitor-left = [];
        move-to-monitor-right = [];
        move-to-monitor-up = [];
        move-to-monitor-down = [];

        # Clear workspace navigation that might conflict
        switch-to-workspace-left = [];
        switch-to-workspace-right = [];
        switch-to-workspace-up = [];
        switch-to-workspace-down = [];
      };

      # Clear any mutter keybindings that might conflict
      "org/gnome/mutter/keybindings" = {
        # Ensure Meta+vim keys are free for Pop Shell
      };

      # Clear shell keybindings that might steal our keys
      "org/gnome/shell/keybindings" = {
        # Ensure nothing in GNOME Shell steals Meta+h/j/k/l
        focus-active-notification = [];
        toggle-message-tray = [];
      };

      # Clear media keys that might conflict
      "org/gnome/settings-daemon/plugins/media-keys" = {
        # Clear lock screen binding (often Super+l) to free it for Pop Shell focus-right
        screensaver = [];  # We'll set this to Super+Escape in tiling.nix

        # Clear any other potential conflicts
        logout = [];
        home = [];
      };

      # Power management settings
      "org/gnome/settings-daemon/plugins/power" = {
        # AC (plugged in) settings - never sleep when plugged in
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-ac-timeout = 0;  # Never sleep on AC

        # Battery settings - reasonable 30 minute timeout
        sleep-inactive-battery-type = "suspend";
        sleep-inactive-battery-timeout = 1800;  # 30 minutes on battery

        # Power button action
        power-button-action = "interactive";

        # Screen brightness and dimming
        idle-brightness = 30;  # Dim to 30% when idle
        idle-dim = true;  # Enable screen dimming

        # Ensure power management is active
        active = true;
      };

      "org/gnome/desktop/session" = {
        idle-delay = 1800;  # 30 minutes before screen dims/blanks
      };

      "org/gnome/desktop/screensaver" = {
        idle-activation-enabled = true;  # Enable automatic screensaver
        lock-enabled = true;  # Enable screen locking
        lock-delay = 1800;  # Lock 30 minutes AFTER screen blanks (total 60 min from idle)
      };

      # Set Vivaldi as default browser in GNOME
      "org/gnome/desktop/default-applications/web" = {
        exec = "vivaldi-stable";
      };

      # Audio settings - set initial volume and mute microphone
      "org/gnome/desktop/sound" = {
        # Set system sound volume to 40%
        event-sounds = true;
      };
    };

    # GNOME-specific MIME overrides - override desktop bundle defaults with GNOME apps
    xdg.mimeApps.defaultApplications = {
      # Text editor - use GNOME Text Editor instead of neovide
      "text/plain" = "org.gnome.TextEditor.desktop";

      # Image viewer - use GNOME Image Viewer instead of imv
      "image/jpeg" = "org.gnome.eog.desktop";
      "image/jpg" = "org.gnome.eog.desktop";
      "image/png" = "org.gnome.eog.desktop";
      "image/gif" = "org.gnome.eog.desktop";
      "image/webp" = "org.gnome.eog.desktop";
      "image/bmp" = "org.gnome.eog.desktop";
      "image/svg+xml" = "org.gnome.eog.desktop";
      "image/tiff" = "org.gnome.eog.desktop";

      # Video player - use GNOME Videos instead of mpv
      "video/mp4" = "org.gnome.Totem.desktop";
      "video/webm" = "org.gnome.Totem.desktop";
      "video/x-matroska" = "org.gnome.Totem.desktop";
      "video/quicktime" = "org.gnome.Totem.desktop";
      "video/x-msvideo" = "org.gnome.Totem.desktop";

      # File manager - use Nautilus instead of thunar
      "inode/directory" = "org.gnome.Nautilus.desktop";
      "application/x-directory" = "org.gnome.Nautilus.desktop";

      # PDF viewer - use GNOME Document Viewer instead of zathura
      "application/pdf" = "org.gnome.Evince.desktop";

      # Archive files - use Nautilus for archive browsing
      "application/zip" = "org.gnome.Nautilus.desktop";
      "application/x-rar" = "org.gnome.Nautilus.desktop";
      "application/x-tar" = "org.gnome.Nautilus.desktop";
      "application/x-7z-compressed" = "org.gnome.Nautilus.desktop";
      "application/gzip" = "org.gnome.Nautilus.desktop";

      # Note: Browser and Office stay as universal defaults (vivaldi + onlyoffice)
    };

    # Note: Universal mimeApps defaults are configured in the desktop bundle
    # This ensures proper handling when both GNOME and Hyprland are enabled

    # Enable SSH to use GNOME keyring for automatic key unlocking
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;  # Explicitly set defaults below
      matchBlocks."*" = {
        addKeysToAgent = "yes";  # Automatically add keys when first used
      };
    };

    # GNOME-compatible packages only
    home.packages = with pkgs; [
      # Core desktop tools that work well with GNOME
      libnotify

      # Media tools
      mpv
      zathura

      # Productivity
      onlyoffice-bin
      obsidian
      bitwarden-desktop

      # Other tools
      virt-manager
    ];

    myHomeManager.impermanence.cache.directories = [
      ".local/state/wireplumber"
    ];

    # Audio initialization service - set volume and mute microphone on boot
    systemd.user.services.gnome-audio-init = {
      Unit = {
        Description = "Initialize GNOME audio settings";
        After = [ "graphical-session.target" "pulseaudio.service" ];
        Wants = [ "pulseaudio.service" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=GNOME";
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "gnome-audio-init" ''
          # Wait for audio system to be ready
          ${pkgs.coreutils}/bin/sleep 3

          # Wait for PulseAudio/PipeWire to be available
          timeout=30
          while [ $timeout -gt 0 ]; do
            if ${pkgs.pulseaudio}/bin/pactl info >/dev/null 2>&1; then
              break
            fi
            ${pkgs.coreutils}/bin/sleep 1
            timeout=$((timeout - 1))
          done

          # Set master volume to 40%
          ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ 40%

          # Mute the microphone
          ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ 1
        '';
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # GNOME power settings enforcement service - ensure dconf settings are applied
    systemd.user.services.gnome-power-settings = {
      Unit = {
        Description = "Enforce GNOME power management settings";
        After = [ "graphical-session.target" ];
        ConditionEnvironment = "XDG_CURRENT_DESKTOP=GNOME";
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "gnome-power-settings" ''
          # Wait for GNOME to be fully loaded
          ${pkgs.coreutils}/bin/sleep 5

          # Force apply power management settings
          ${pkgs.glib}/bin/gsettings set org.gnome.desktop.session idle-delay 1800
          ${pkgs.glib}/bin/gsettings set org.gnome.desktop.screensaver idle-activation-enabled true
          ${pkgs.glib}/bin/gsettings set org.gnome.desktop.screensaver lock-enabled true
          ${pkgs.glib}/bin/gsettings set org.gnome.desktop.screensaver lock-delay 1800
        '';
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
