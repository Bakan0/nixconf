{ config, lib, pkgs, ... }:

{
  programs.foot = {
    enable = true;
    settings = {
      main = {
        # Match kitty's font size (13pt)
        font = "monospace:size=13";
        dpi-aware = "yes";

        # Shell integration (foot has native shell integration)
        shell = "${pkgs.fish}/bin/fish";

        # Padding (similar to kitty's window padding)
        pad = "2x2";

        # Line height adjustment (kitty: adjust_line_height = 0)
        # foot uses line-height as a multiplier, 1.0 = default
        line-height = "1.0";

        # Letter spacing (kitty: adjust_column_width = 0)
        # foot uses letter-spacing in points, 0 = default
        letter-spacing = "0";
      };

      bell = {
        # Match kitty's enable_audio_bell = no
        urgent = "no";
        notify = "no";
        command = null;
        command-focused = "no";
      };

      cursor = {
        # Cursor styling
        style = "block";
        blink = "yes";
        # Match kitty's cursor behavior
        color = "inverse";  # This makes cursor use inverse of text color
      };

      scrollback = {
        # Scrollback configuration
        lines = 10000;

        # Scrollback search/viewing
        # foot uses $PAGER or less by default for scrollback viewing
        # For nvim integration, we can set a custom command
        multiplier = "3.0";  # Scroll speed
      };

      url = {
        # URL detection and launching
        launch = "xdg-open \${url}";
        label-letters = "sadfjklewcmpgh";
        osc8-underline = "url-mode";
        protocols = "http, https, ftp, ftps, file, gemini, gopher, irc, ircs, kitty, mailto, news, sftp, ssh";
        uri-characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~:/?#[]@!$&'()*+,;=%";
      };

      mouse = {
        # Mouse behavior
        hide-when-typing = "yes";
        alternate-scroll-mode = "yes";  # Better scrolling in apps like vim
      };

      # Key bindings for similar functionality to kitty
      key-bindings = {
        # Scrollback with Shift+PageUp/PageDown (default in foot)
        # Copy/paste
        clipboard-copy = "Control+Shift+c XF86Copy";
        clipboard-paste = "Control+Shift+v XF86Paste";

        # Search in scrollback (similar to kitty's scrollback search)
        search-start = "Control+Shift+slash";

        # Font size adjustment
        font-increase = "Control+plus Control+equal Control+KP_Add";
        font-decrease = "Control+minus Control+KP_Subtract";
        font-reset = "Control+0 Control+KP_0";

        # Spawn new instance in same directory
        spawn-terminal = "Control+Shift+n";

        # Show URLs (similar to kitty's hints)
        show-urls-launch = "Control+Shift+u";
        show-urls-copy = "Control+Shift+y";

        # Pipe scrollback to external program (for nvim integration)
        # This is similar to kitty's scrollback_pager
        pipe-scrollback = "Control+Shift+h sh -c 'cat > /tmp/foot_scrollback && nvim /tmp/foot_scrollback'";
      };

      # Colors will be handled by Stylix
      colors = {
        # Stylix will override these
      };
    };
  };
}