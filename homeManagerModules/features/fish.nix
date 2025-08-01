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
    };

    shellInit = ''
      set fish_greeting

      set -x EDITOR nvim

      set -s PATH $HOME/bin $PATH
    '';

    shellAliases = {
      lf = "lfcd";
      os = "nh os";
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
