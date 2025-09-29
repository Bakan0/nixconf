{
  pkgs,
  config,
  lib,
  ...
}: {
  # GNOME Hyprland-style keybindings configuration
  # Provides comprehensive keybinding setup for tiling window management
  # Only applies when both gnome and tiling are enabled

  dconf.settings = {
      # Clear GNOME keybindings that conflict with Pop Shell tiling
      # These are set to empty to prevent interference with Pop Shell's vim navigation
      "org/gnome/desktop/wm/keybindings" = {
        # Clear directional movement keys for Pop Shell
        move-to-monitor-left = [];
        move-to-monitor-right = [];
        move-to-monitor-up = [];
        move-to-monitor-down = [];

        # Window operations
        close = ["<Super>q"];
        toggle-fullscreen = ["<Super>f"];
        toggle-maximized = ["<Super>m"];
        minimize = ["<Super>n"];

        # CRITICAL: Toggle always-on-top for current window (Super+Shift+T)
        # Use this to keep floating windows visible above tiled windows
        always-on-top = ["<Super><Shift>t"];

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
        # maximize and unmaximize defined above

        # Additional Hyprland-like bindings
        switch-to-workspace-left = ["<Super>comma"];
        switch-to-workspace-right = ["<Super>period"];
        move-to-workspace-left = ["<Super><Shift>comma"];
        move-to-workspace-right = ["<Super><Shift>period"];
      };

      # Custom keybindings (Hyprland-style)
      "org/gnome/settings-daemon/plugins/media-keys" = {
        # Clear media keys that might conflict with tiling
        # Clear lock screen binding (often Super+l) to free it for Pop Shell focus-right
        screensaver = ["<Super>Escape"];  # Set this to Super+Escape

        # Clear any other potential conflicts
        logout = [];
        home = [];

        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/filemanager/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/logout/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clipboard-paste/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/clear-notifications/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/float-window-on-top/"
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

      # GNOME shell keybindings configuration
      "org/gnome/shell/keybindings" = {
        # Clear conflicting keybindings and set custom ones
        focus-active-notification = [];
        show-screenshot-ui = ["<Super><Shift>s"];  # Screenshot UI with Super+Shift+S
        toggle-quick-settings = [];  # Disable Super+S for quick settings (now free for application launcher)
        toggle-application-view = ["<Super>s"];  # App grid - escapes to overview (GNOME limitation)
        toggle-overview = ["<Super>a"];  # Activities overview with Meta+A
        toggle-message-tray = ["<Super>i"];  # Show/hide notifications with Meta+I
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

      # Pop Shell keybindings configuration
      "org/gnome/shell/extensions/pop-shell" = {
        # Pop Shell keybindings (vim-style navigation)
        focus-left = ["<Super>h"];
        focus-down = ["<Super>j"];
        focus-up = ["<Super>k"];
        focus-right = ["<Super>l"];

        # Direct window movement WITHOUT management mode (global)
        # Super+Shift+vim to move focused window around instantly
        tile-move-left-global = ["<Super><Shift>h"];
        tile-move-down-global = ["<Super><Shift>j"];
        tile-move-up-global = ["<Super><Shift>k"];
        tile-move-right-global = ["<Super><Shift>l"];

        # Tile management mode for resizing (Super+T) - only needed for resize operations
        tile-enter = ["<Super>t"];


        # Toggle floating for current window (Super+Shift+F for "float" like Hyprland)
        toggle-floating = ["<Super><Shift>f"];

        # Toggle stacking mode WITHOUT management mode (Super+G for "group")
        toggle-stacking = ["<Super>g"];

        # Global stacking toggle - works without management mode (Super+\ for unstacking)
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

        # Window swapping (Super+Ctrl+vim) - these don't have global variants
        tile-swap-left = ["<Super><Ctrl>h"];
        tile-swap-down = ["<Super><Ctrl>j"];
        tile-swap-up = ["<Super><Ctrl>k"];
        tile-swap-right = ["<Super><Ctrl>l"];

        # Window resizing in management mode (h/j/k/l without modifiers)
        tile-resize-left = ["h"];
        tile-resize-down = ["j"];
        tile-resize-up = ["k"];
        tile-resize-right = ["l"];

        # Management mode controls
        tile-accept = ["Return"];
        tile-reject = ["Escape"];

        # Management mode movement (disabled - we use global variants)
        tile-move-left = [];
        tile-move-down = [];
        tile-move-up = [];
        tile-move-right = [];

        # Disable broken Pop Shell launcher
        activate-launcher = [];
      };
    };
}
