{
  pkgs,
  config,
  lib,
  ...
}: {
  # Always import keybindings.nix - it will only apply if both gnome and tiling are enabled
  imports = [ ./keybindings.nix ];


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
      clipboard-indicator        # Clipboard manager
    ]) ++ (with pkgs; [
      # Additional tools for functionality parity
      dconf-editor               # For GNOME configuration
      gnome-tweaks               # Additional GNOME settings
      wmctrl                     # Window management commands (X11 compatibility)
      xdotool                    # Additional automation (X11 compatibility)
    ]);

    # GNOME settings via dconf
    dconf.settings = {

      # Clear any mutter keybindings that might conflict with tiling
      "org/gnome/mutter/keybindings" = {
        # Ensure Meta+vim keys are free for Pop Shell
      };

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
        # CRITICAL: Keep floating windows on top
        keep-on-top = true;  # Windows marked as always-on-top stay above others
      };

      "org/gnome/desktop/wm/preferences" = {
        num-workspaces = 10;  # Use all number keys 1-9,0
        workspace-names = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" ];
        focus-mode = "sloppy";  # CRITICAL: Use sloppy focus - mouse hover focuses window
        auto-raise = false;      # DON'T auto-raise windows - prevents floating windows from disappearing
        auto-raise-delay = 500;  # Slower auto-raise if ever re-enabled
        button-layout = ":minimize,maximize,close";  # Window buttons on right
        resize-with-right-button = true;
        # Raise windows on click to bring them forward
        raise-on-click = true;
      };





      # Pop Shell tiling configuration
      "org/gnome/shell/extensions/pop-shell" = {
        # Core tiling settings
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

        # CRITICAL: Mouse cursor MUST follow active window and center on it
        mouse-cursor-follows-active-window = true;   # Enable cursor following focus
        mouse-cursor-focus-location = lib.hm.gvariant.mkUint32 4;  # 4=center mouse on window

        float-all-windows = false;  # Don't float all windows by default
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


      # Top Bar Organizer - move clock to left of quick settings
      "org/gnome/shell/extensions/top-bar-organizer" = {
        # Move clock (dateMenu) to the left of quick settings menu
        right-box-order = ["dateMenu" "quickSettings"];  # Put dateMenu before quickSettings
      };

      # Notification Position - move notifications to right side under clock
      "org/gnome/shell/extensions/notification-position" = {
        # Move notifications to top-right (under the clock area)
        banner-pos = 2;  # 0=top-left, 1=top-center, 2=top-right
      };

      "org/gnome/desktop/notifications" = {
        show-in-lock-screen = false;
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