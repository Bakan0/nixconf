{
  pkgs,
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.myHomeManager.gnome.enable && config.myHomeManager.gnome.tiling.enable) {
    # Hyprland-like tiling configuration for GNOME
    # Provides tiling window management, keybindings, and behaviors similar to Hyprland

    # Fix Pop Shell schema accessibility - ensure schemas are properly compiled
    xdg.dataFile."glib-2.0/schemas/org.gnome.shell.extensions.pop-shell.gschema.xml" = {
      source = "${pkgs.gnomeExtensions.pop-shell}/share/gnome-shell/extensions/pop-shell@system76.com/schemas/org.gnome.shell.extensions.pop-shell.gschema.xml";
    };

    # Compile the schemas after installation
    home.activation.compilePopShellSchemas = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -f "$HOME/.local/share/glib-2.0/schemas/org.gnome.shell.extensions.pop-shell.gschema.xml" ]; then
        run ${pkgs.glib.dev}/bin/glib-compile-schemas "$HOME/.local/share/glib-2.0/schemas"
      fi
    '';

    # GNOME extensions for Hyprland-like functionality
    home.packages = (with pkgs.gnomeExtensions; [
      # Essential extensions for Hyprland-like experience
      user-themes                # Custom shell themes support
      appindicator               # System tray support (KStatusNotifierItem)
      # Window and workspace management
      pop-shell                  # Tiling window management

      # Visual enhancements
      blur-my-shell              # Blur effects like Hyprland
      rounded-corners            # Rounded corners like Hyprland

      # System monitoring
      net-speed-simplified       # Network speed indicator
      vitals                     # Additional system vitals

      # Workspace and UI improvements
      just-perfection            # UI tweaks and customization
      top-bar-organizer          # Organize panel elements - move clock far right
      notification-banner-position  # Move notifications to right side under clock

      # Optional/alternative extensions
      compiz-windows-effect      # Additional window effects
      clipboard-indicator        # Clipboard manager
    ]) ++ (with pkgs; [
      # Additional tools for functionality parity
      dconf-editor               # For GNOME configuration
      gnome-tweaks               # Additional GNOME settings
      wmctrl                     # Window management commands
      xdotool                    # Additional automation
    ]);

    # GNOME settings via dconf
    dconf.settings = {
      # Enable extensions
      "org/gnome/shell" = {
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "pop-shell@system76.com"
          "blur-my-shell@aunetx"
          "rounded-window-corners@yilozt"
          "netspeed@alynx.one"
          "Vitals@CoreCoding.com"
          "just-perfection-desktop@just-perfection"
          "top-bar-organizer@julian.gse.jsts.xyz"
          "notification-position@drugo.dev"
          "compiz-windows-effect@hermes83.github.com"
          "clipboard-indicator@tudmotu.com"
        ];

        # Favorite apps for dock/panel
        favorite-apps = [
          "kitty.desktop"
          "vivaldi-stable.desktop"
          "thunar.desktop"
          "signal-desktop.desktop"
          "obsidian.desktop"
        ];
      };

      # Workspace behavior
      "org/gnome/mutter" = {
        edge-tiling = true;
        dynamic-workspaces = false;  # Static workspaces so they all exist
        workspaces-only-on-primary = false;   # Allow workspaces on all monitors
        center-new-windows = true;
        auto-maximize = false;  # Don't auto-maximize windows (let Pop Shell tile them)
        focus-change-on-pointer-rest = false;  # Don't wait for pointer to rest
        experimental-features = ["scale-monitor-framebuffer"];  # Enable fractional scaling
        overlay-key = "";  # Disable Super key alone (like Hyprland) to prevent interference
        attach-modal-dialogs = false;  # Allow modal dialogs to float freely
      };

      "org/gnome/desktop/wm/preferences" = {
        num-workspaces = 10;  # Use all number keys 1-9,0
        workspace-names = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" ];
        focus-mode = "sloppy";  # Follow mouse focus like Hyprland
        auto-raise = true;      # Auto-raise focused windows
        auto-raise-delay = 25;  # Super fast auto-raise (25ms)
        button-layout = ":minimize,maximize,close";  # Window buttons on right
        resize-with-right-button = true;
      };

      # Window management keybindings (Hyprland-style)
      "org/gnome/desktop/wm/keybindings" = {
        # Window operations
        close = ["<Super>q"];
        toggle-fullscreen = ["<Super>f"];
        toggle-maximized = ["<Super>m"];
        minimize = ["<Super>n"];

        # Workspace switching - Meta+1,2,3... switches TO workspace
        switch-to-workspace-1 = ["<Super>1"];
        switch-to-workspace-2 = ["<Super>2"];
        switch-to-workspace-3 = ["<Super>3"];
        switch-to-workspace-4 = ["<Super>4"];
        switch-to-workspace-5 = ["<Super>5"];
        switch-to-workspace-6 = ["<Super>6"];
        switch-to-workspace-7 = ["<Super>7"];
        switch-to-workspace-8 = ["<Super>8"];
        switch-to-workspace-9 = ["<Super>9"];
        switch-to-workspace-10 = ["<Super>0"];

        # Window movement to workspaces - Shift+Meta+1,2,3... MOVES window to workspace
        move-to-workspace-1 = ["<Super><Shift>1"];
        move-to-workspace-2 = ["<Super><Shift>2"];
        move-to-workspace-3 = ["<Super><Shift>3"];
        move-to-workspace-4 = ["<Super><Shift>4"];
        move-to-workspace-5 = ["<Super><Shift>5"];
        move-to-workspace-6 = ["<Super><Shift>6"];
        move-to-workspace-7 = ["<Super><Shift>7"];
        move-to-workspace-8 = ["<Super><Shift>8"];
        move-to-workspace-9 = ["<Super><Shift>9"];
        move-to-workspace-10 = ["<Super><Shift>0"];

        # Directional window switching (vim keys)
        switch-windows = ["<Super>Tab"];
        switch-applications = ["<Super><Shift>Tab"];
        cycle-windows = ["<Alt>Tab"];

        # Window tiling operations - DISABLED to let Pop Shell handle vim keys
        toggle-tiled-left = [];
        toggle-tiled-right = [];
        maximize = [];
        unmaximize = [];

        # Additional Hyprland-like bindings
        switch-to-workspace-left = ["<Super>comma"];
        switch-to-workspace-right = ["<Super>period"];
        move-to-workspace-left = ["<Super><Shift>comma"];
        move-to-workspace-right = ["<Super><Shift>period"];
      };

      # Custom keybindings (Hyprland-style)
      "org/gnome/settings-daemon/plugins/media-keys" = {
        # Native GNOME lock screen (Meta+Escape)
        screensaver = ["<Super>Escape"];

        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/filemanager/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/logout/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/screenshot-clip/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/screenshot-file/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clipboard-paste/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clear-notifications/"
        ];

        # Media keys
        volume-up = ["XF86AudioRaiseVolume"];
        volume-down = ["XF86AudioLowerVolume"];
        volume-mute = ["XF86AudioMute"];

        # Disable built-in screenshot keys (we'll use custom keybindings)
        screenshot = [];  # Disable full screen screenshot
        screenshot-window = [];  # Disable window screenshot

        # Disable accessibility shortcuts that conflict
        screenreader = [];  # Was Alt+Super+S - conflicts with screenshot
        magnifier = [];
        magnifier-zoom-in = [];
        magnifier-zoom-out = [];
      };

      # Disable GNOME's conflicting keybindings
      "org/gnome/shell/keybindings" = {
        show-screenshot-ui = [];  # Disable default screenshot UI
        toggle-quick-settings = [];  # Disable Super+S for quick settings (now free for application launcher)
        toggle-application-view = ["<Super>s"];  # App grid - escapes to overview (GNOME limitation)
        toggle-overview = ["<Super>a"];  # Activities overview with Meta+A
        toggle-message-tray = ["<Super>i"];  # Show/hide notifications with Meta+I
        screenshot = [];  # Disable default screenshot
        screenshot-window = [];  # Disable default window screenshot

        # CRITICAL: Disable switch-to-application bindings that steal Super+1-9
        switch-to-application-1 = [];
        switch-to-application-2 = [];
        switch-to-application-3 = [];
        switch-to-application-4 = [];
        switch-to-application-5 = [];
        switch-to-application-6 = [];
        switch-to-application-7 = [];
        switch-to-application-8 = [];
        switch-to-application-9 = [];
      };

      # Terminal keybinding (Super+Return like Hyprland)
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal" = {
        name = "Terminal";
        command = "kitty";
        binding = "<Super>Return";
      };


      # File manager keybinding
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/filemanager" = {
        name = "File Manager";
        command = "thunar";
        binding = "<Super>e";
      };


      # Logout immediately (like hyprctl dispatch exit)
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/logout" = {
        name = "Logout Immediately";
        command = "gnome-session-quit --no-prompt --force";
        binding = "<Super><Shift>m";
      };

      # Screenshot area using GNOME's built-in screenshot UI keybinding
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/screenshot-clip" = {
        name = "Screenshot Area";
        command = "sh -c 'ydotool key shift+Print'";  # Shift+Print triggers area selection in GNOME
        binding = "<Super><Shift>s";
      };

      # Screenshot area to file - same as above (GNOME saves both to clipboard and file)
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/screenshot-file" = {
        name = "Screenshot Area to File";
        command = "sh -c 'ydotool key shift+Print'";  # Shift+Print triggers area selection
        binding = "<Super><Alt>s";
      };

      # Paste clipboard contents
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clipboard-paste" = {
        name = "Paste Clipboard Contents";
        command = "sh -c 'wl-paste | wtype -'";
        binding = "<Super>v";
      };

      # Clear all notifications
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clear-notifications" = {
        name = "Clear All Notifications";
        command = "gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval 'Main.panel.statusArea.dateMenu._messageList._sectionList.get_children().forEach(s => s.clear())'";
        binding = "<Super><Shift>i";
      };






      # Blur my Shell configuration (enhanced settings)
      "org/gnome/shell/extensions/blur-my-shell" = {
        # Global blur settings
        brightness = 0.85;  # ~85% brightness
        sigma = 100;  # Maximum blur radius
      };

      # Panel blur
      "org/gnome/shell/extensions/blur-my-shell/panel" = {
        blur = true;
        brightness = 0.85;
        sigma = 100;
        customize = true;
      };

      # Overview blur
      "org/gnome/shell/extensions/blur-my-shell/overview" = {
        blur = true;
        brightness = 0.85;
        sigma = 100;
      };

      # Application blur
      "org/gnome/shell/extensions/blur-my-shell/applications" = {
        blur = true;
        brightness = 0.85;
        sigma = 100;
        enable-all = true;  # Enable blur for all applications by default
      };

      # Default dash blur (stock GNOME panel)
      "org/gnome/shell/extensions/blur-my-shell/dash-to-dock" = {
        blur = true;
        brightness = 0.85;
        sigma = 100;
        customize = true;
      };

      # Rounded corners configuration (reduced radius)
      "org/gnome/shell/extensions/rounded-window-corners" = {
        global-rounded-corner-settings = ''{"padding": <{"top": <uint32 0>, "left": <uint32 0>, "right": <uint32 0>, "bottom": <uint32 0>}>, "keep_rounded_corners": <{"maximized": <false>, "fullscreen": <false>}>, "border_radius": <uint32 20>, "smoothing": <0.5>}'';
        settings-version = 5;
      };

      # Pop Shell tiling configuration
      "org/gnome/shell/extensions/pop-shell" = {
        tile-by-default = true;
        gap-inner = lib.mkDefault 5;
        gap-outer = lib.mkDefault 10;
        smart-gaps = false;
        snap-to-grid = true;
        show-title = false;
        active-hint = true;
        active-hint-border-radius = lib.mkDefault 5;

        # IMPORTANT: Disable stacking (windows on top of each other)
        stacking-with-mouse = false;
        mouse-cursor-follows-active-window = true;   # Enable cursor following focus
        mouse-cursor-focus-location = lib.hm.gvariant.mkUint32 4;  # 0=top-left, 1=top-right, 4=center

        float-all-windows = false;  # Don't float all windows by default

        # Pop Shell keybindings (vim-style navigation)
        focus-left = ["<Super>h"];
        focus-down = ["<Super>j"];
        focus-up = ["<Super>k"];
        focus-right = ["<Super>l"];

        # Move/swap windows WITHIN workspace (non-management mode)
        # Super+Shift+vim to move focused window around
        swap-left = ["<Super><Shift>h"];
        swap-down = ["<Super><Shift>j"];
        swap-up = ["<Super><Shift>k"];
        swap-right = ["<Super><Shift>l"];

        # Window management mode (Super+T for "tiling")
        tile-enter = ["<Super>t"];

        # Toggle floating for current window (Super+Shift+F for "float" like Hyprland)
        toggle-floating = ["<Super><Shift>f"];

        # Toggle stacking mode (Super+G for "group" like Hyprland)
        toggle-stacking = ["<Super>g"];

        # Remove from stack/group (Super+\ like Hyprland)
        toggle-stacking-global = ["<Super>backslash"];

        # CRITICAL: Disable toggle-tiling to stop Meta+Y from disabling ALL tiling
        toggle-tiling = [];

        # Move windows WITHIN workspace with Meta+Shift+vim keys (like Hyprland movewindow)
        # These don't exist as direct Pop Shell bindings, will use tile-move in non-management mode

        # Move windows between MONITORS with Meta+Alt+vim keys
        pop-monitor-left = ["<Super><Alt>h"];
        pop-monitor-down = ["<Super><Alt>j"];
        pop-monitor-up = ["<Super><Alt>k"];
        pop-monitor-right = ["<Super><Alt>l"];

        # Move to different workspace
        pop-workspace-down = ["<Super><Control>j"];
        pop-workspace-up = ["<Super><Control>k"];

        # In management mode: Shift windows around
        tile-move-left = ["<Super><Shift>h"];
        tile-move-down = ["<Super><Shift>j"];
        tile-move-up = ["<Super><Shift>k"];
        tile-move-right = ["<Super><Shift>l"];

        # In management mode: Swap windows
        tile-swap-left = ["<Super><Ctrl>h"];
        tile-swap-down = ["<Super><Ctrl>j"];
        tile-swap-up = ["<Super><Ctrl>k"];
        tile-swap-right = ["<Super><Ctrl>l"];

        # In management mode: Resize windows
        tile-resize-left = ["h"];
        tile-resize-down = ["j"];
        tile-resize-up = ["k"];
        tile-resize-right = ["l"];

        # Accept changes in management mode
        tile-accept = ["Return"];

        # Reject/cancel management mode
        tile-reject = ["Escape"];

        # Disable broken Pop Shell launcher
        activate-launcher = [];
      };




      # Net Speed Simplified - also position early in right section
      "org/gnome/shell/extensions/netspeedsimplified" = {
        mode = 0;  # Show both up and down speeds
        fontmode = 0;  # Use default font
        refreshtime = 2.0;  # Update every 2 seconds
        togglebool = false;  # Don't toggle between modes
      };


      # Just Perfection tweaks
      "org/gnome/shell/extensions/just-perfection" = {
        workspace-wrap-around = true;  # Wrap from workspace 10 back to 1
        workspace-peek = true;  # Preview workspace on hover
        animation = 4;  # Fastest animations
        enable-animations-on-startup = true;
        panel = true;
        panel-in-overview = true;
        double-super-to-appgrid = false;
        startup-status = 0;  # Start on desktop, not overview (0=desktop, 1=overview)
        window-demands-attention-focus = true;
        window-maximized-on-create = false;
        workspace-popup = false;  # Disable default workspace switcher popup
        workspace-switcher-size = 0;  # Hide workspace switcher
        workspaces-in-app-grid = false;
      };

      # Input settings (matching Hyprland)
      "org/gnome/desktop/peripherals/touchpad" = {
        natural-scroll = true;
        tap-to-click = true;
        click-method = "fingers";
        disable-while-typing = true;
        speed = 0.3;
      };

      "org/gnome/desktop/peripherals/keyboard" = {
        repeat = true;
        repeat-interval = lib.mkDefault 25;  # 40Hz equivalent
        delay = lib.mkDefault 250;
      };

      # Mouse settings
      "org/gnome/desktop/peripherals/mouse" = {
        natural-scroll = true;
        speed = 0.0;
        accel-profile = "flat";  # No acceleration like Hyprland
      };


      # Interface settings - match waybar clock format
      "org/gnome/desktop/interface" = {
        enable-animations = true;
        cursor-theme = "Bibata-Modern-Amber";  # Keep the amber cursor theme
        cursor-size = 24;
        # Icon theme is set via stylix
        font-antialiasing = "rgba";
        font-hinting = "slight";
        enable-hot-corners = false;

        # Clock settings to match waybar format: "󰃰 {:%A, %B %d, %Y (%H:%M:%S)}"
        clock-show-seconds = true;      # Show seconds like waybar
        clock-show-weekday = true;      # Show weekday like waybar
        clock-show-date = true;         # Show full date
        show-battery-percentage = true;
        animation-duration = 100;       # Faster animations globally (milliseconds)
      };

      # Panel transparency and styling to match waybar
      "org/gnome/shell" = {
        # Already configured above with extensions
      };


      # Top Bar Organizer - move clock to far right past quick settings
      "org/gnome/shell/extensions/top-bar-organizer" = {
        # Move clock (dateMenu) to the far right - past all system indicators
        right-box-order = ["quickSettings" "dateMenu"];  # Put dateMenu after quickSettings
      };

      # Notification Position - move notifications to right side under clock
      "org/gnome/shell/extensions/notification-position" = {
        # Move notifications to top-right (under the clock area)
        banner-pos = 2;  # 0=top-left, 1=top-center, 2=top-right
      };

      # Default applications
      "org/gnome/system/proxy" = {
        mode = "none";
      };

    };

    # Environment variables
    home.sessionVariables = {
      # These will be overridden by Stylix if enabled
      XCURSOR_THEME = lib.mkDefault "Bibata-Modern-Amber";
      XCURSOR_SIZE = lib.mkDefault "24";
    };

  };
}