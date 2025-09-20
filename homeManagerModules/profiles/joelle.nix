{ config, pkgs, ... }:

{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      bat
      fzf
    ];
  };

  # Joelle's minimal configuration
  myHomeManager = {
    # Individual features, no heavy bundles
    nvim.enable = true;
    fish.enable = false;
    zsh.enable = false;
    git.enable = true;
    kitty.enable = true;
    firefox.enable = true;
    stylix.enable = true;
    stylix.theme = "crimson-noir";
  };

  programs = {
    home-manager.enable = true;
    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
