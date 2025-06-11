{ config, pkgs, ... }:

{
  home = {
    username = "joelle";
    homeDirectory = "/home/joelle";
    stateVersion = "24.05";

    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      ripgrep
      fd
      jq
      bat
      eza
      fzf
      htop
    ];
  };

  myHomeManager = {
    # Try enabling features individually instead of bundles
    # bundles.general.enable = true;
    # bundles.desktop.enable = true;

    fish.enable = false;
    zsh.enable = false;  # Temporarily disable zsh to see if it's the culprit
    git.enable = true;
    kitty.enable = true;
    firefox.enable = true;
    stylix.enable = false;
  };

  programs = {
    home-manager.enable = true;
    nix-index = {
      enable = true;
      enableZshIntegration = false;  # Disable zsh integration too
    };
  };
}
