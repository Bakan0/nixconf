{
  inputs,
  pkgs,
  ...
}: {
  programs.fish = {
    enable = true;

    functions = {
      fish_prompt = {
        body = ''
          string join "" -- (set_color red) "[" (set_color yellow) $USER (set_color green) "@" (set_color blue) $hostname (set_color magenta) " " $(prompt_pwd) (set_color red) ']' (set_color normal) "\$ "
        '';
      };

      # lfcd = {
      #   body = ''
      #     cd "$(command lf -print-last-dir $argv)"
      #   '';
      # };

      hst = {
        body = ''
          history | uniq | ${pkgs.fzf}/bin/fzf | ${pkgs.wl-clipboard}/bin/wl-copy -n
        '';
      };

      # SSH agent helper
      ssh-check = {
        body = ''
          if test -n "$SSH_AUTH_SOCK"
            echo "SSH agent available (forwarded: $SSH_CONNECTION)"
            ssh-add -l
          else
            echo "No SSH agent available"
          end
        '';
      };

      # Project navigation from zsh config
      proj = {
        body = ''
          set dir (cat ~/.local/share/direnv/allow/* | uniq | xargs dirname | ${pkgs.fzf}/bin/fzf --height 9)
          if test -n "$dir"
            cd "$dir"
          end
        '';
      };

      # Combined project navigation + lf
      plf = {
        body = ''
          proj
          lf
        '';
      };

      # Detach process (run in background)
      detach = {
        body = ''
          set prog $argv[1]
          set -e argv[1]
          nohup setsid $prog $argv >/dev/null 2>&1 &
        '';
      };

      # Extract function - universal archive extractor
      ex = {
        body = ''
          if test -f $argv[1]
            switch $argv[1]
              case "*.tar.bz2"
                tar xjf $argv[1]
              case "*.tar.gz"
                tar xzf $argv[1]
              case "*.bz2"
                bunzip2 $argv[1]
              case "*.rar"
                ${pkgs.unrar}/bin/unrar x $argv[1]
              case "*.gz"
                gunzip $argv[1]
              case "*.tar"
                tar xf $argv[1]
              case "*.tbz2"
                tar xjf $argv[1]
              case "*.tgz"
                tar xzf $argv[1]
              case "*.zip"
                ${pkgs.unzip}/bin/unzip $argv[1]
              case "*.Z"
                uncompress $argv[1]
              case "*.7z"
                7z x $argv[1]
              case "*.deb"
                ar x $argv[1]
              case "*.tar.xz"
                tar xf $argv[1]
              case "*.tar.zst"
                tar xf $argv[1]
              case "*"
                echo "'$argv[1]' cannot be extracted via ex()"
            end
          else
            echo "'$argv[1]' is not a valid file"
          end
        '';
      };

      # Create file and directories - like zsh mk function
      mk = {
        body = ''
          mkdir -p (dirname $argv[1])
          touch $argv[1]
        '';
      };
    };

    shellInit = ''
      set fish_greeting

      # Environment variables from zsh config
      set -x EDITOR nvim
      set -x TERMINAL kitty
      set -x TERM kitty
      set -x BROWSER vivaldi
      set -x VIDEO mpv
      set -x IMAGE imv
      set -x OPENER xdg-open
      set -x LAUNCHER "rofi -dmenu"
      set -x FZF_DEFAULT_OPTS "--color=16"

      # Less colors (from zsh config)
      set -x LESS_TERMCAP_mb \e'[1;32m'
      set -x LESS_TERMCAP_md \e'[1;32m'
      set -x LESS_TERMCAP_me \e'[0m'
      set -x LESS_TERMCAP_se \e'[0m'
      set -x LESS_TERMCAP_so \e'[01;33m'
      set -x LESS_TERMCAP_ue \e'[0m'
      set -x LESS_TERMCAP_us \e'[1;4;31m'

      # direnv
      set -x DIRENV_LOG_FORMAT ""

      set -s PATH $HOME/bin $PATH

      # Start SSH agent if not already running
      if not set -q SSH_AUTH_SOCK
        eval (ssh-agent -c) >/dev/null
      end
    '';

    shellAliases = {
      # File management
      lf = "lfcd";
      ls = "${pkgs.eza}/bin/eza --icons -a --group-directories-first";
      tree = "${pkgs.eza}/bin/eza --color=auto --tree";

      # System management
      os = "nh os";

      # Convenience aliases from zsh config
      cal = "cal -s";
      grep = "grep --color=auto";
      q = "exit";
      ":q" = "exit";
    };

    # setup vi mode
    interactiveShellInit = ''
      fish_vi_key_bindings
    '';
  };

  myHomeManager.impermanence.cache.directories = [
    ".local/share/fish"
  ];
}
