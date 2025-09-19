{
  inputs,
  pkgs,
  config,
  ...
}: {
  # Robust backup handling - remove existing backup files before Home Manager creates new ones
  home.activation.cleanFishBackups = config.lib.dag.entryBefore ["linkGeneration"] ''
    if [ -f "$HOME/.config/fish/config.fish.backup" ]; then
      rm -f "$HOME/.config/fish/config.fish.backup"
      echo "Removed existing fish config backup"
    fi
    if [ -f "$HOME/.config/fish/functions/fish_prompt.fish.backup" ]; then
      rm -f "$HOME/.config/fish/functions/fish_prompt.fish.backup"
      echo "Removed existing fish_prompt backup"
    fi
  '';

  programs.fish = {
    enable = true;

    functions = {
      fish_prompt = {
        body = ''
          string join "" -- (set_color "${config.stylix.base16Scheme.base09}") $USER (set_color "${config.stylix.base16Scheme.base0B}") "@" $hostname (set_color normal) " " $(prompt_pwd) " \$ "
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
          if test -d ~/.local/share/direnv/allow
            set dir (cat ~/.local/share/direnv/allow/* 2>/dev/null | uniq | xargs dirname 2>/dev/null | ${pkgs.fzf}/bin/fzf --height 9)
            if test -n "$dir"
              cd "$dir"
            end
          else
            echo "No direnv projects found. Use 'direnv allow' in project directories first."
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

      fish_add_path $HOME/bin

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

    # setup vi mode but disable mode display
    interactiveShellInit = ''
      fish_vi_key_bindings
      function fish_mode_prompt; end
    '';
  };

  myHomeManager.impermanence.cache.directories = [
    ".local/share/fish"
  ];
}
