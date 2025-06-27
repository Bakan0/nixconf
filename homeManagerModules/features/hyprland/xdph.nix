{ config, lib, ... }: {
  # https://www.reddit.com/r/hyprland/comments/1g6p5hq/does_anyone_also_have_this/
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      allow_token_by_default = true
    }
  '';
}

