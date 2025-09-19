{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.foot = {
    enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        pad = "4x4";
      };

      mouse = {
        hide-when-typing = "yes";
      };

      scrollback = {
        lines = 10000;
      };

      url = {
        launch = "xdg-open \${url}";
      };

      cursor = {
        style = "beam";
        blink = "yes";
      };

      key-bindings = {
        show-urls-launch = "Control+Shift+u";
        unicode-input = "Control+Shift+i";
        scrollback-up-page = "Shift+Page_Up";
        scrollback-down-page = "Shift+Page_Down";
        clipboard-copy = "Control+Shift+c XF86Copy";
        clipboard-paste = "Control+Shift+v XF86Paste";
        primary-paste = "Shift+Insert";
        search-start = "Control+Shift+f";
        font-increase = "Control+plus Control+equal Control+KP_Add";
        font-decrease = "Control+minus Control+KP_Subtract";
        font-reset = "Control+0 Control+KP_0";
        spawn-terminal = "Control+Shift+n";
        show-urls-copy = "none";
        show-urls-persistent = "none";
        noop = "none";
      };

      search-bindings = {
        cancel = "Control+g Control+c Escape";
        commit = "Return";
        find-prev = "Control+r";
        find-next = "Control+s";
        cursor-left = "Left Control+b";
        cursor-left-word = "Control+Left";
        cursor-right = "Right Control+f";
        cursor-right-word = "Control+Right";
        cursor-home = "Home Control+a";
        cursor-end = "End Control+e";
        delete-prev = "BackSpace";
        delete-prev-word = "Control+BackSpace";
        delete-next = "Delete Control+d";
        delete-next-word = "Control+Delete";
        extend-char = "Shift+Right";
        extend-to-word-boundary = "Control+Shift+Right";
        extend-to-next-whitespace = "Control+Shift+w";
        extend-line-down = "Shift+Down";
        extend-backward-char = "Shift+Left";
        extend-backward-to-word-boundary = "Control+Shift+Left";
        extend-backward-to-next-whitespace = "none";
        extend-line-up = "Shift+Up";
        clipboard-paste = "Control+v Control+Shift+v Control+y XF86Paste";
        primary-paste = "Shift+Insert";
        unicode-input = "none";
      };
    };
  };
}