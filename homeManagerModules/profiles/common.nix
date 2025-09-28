{ config, pkgs, lib, ... }:

{
  # Universal settings for ALL users
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Core bundle that everyone needs
  myHomeManager.bundles.general.enable = lib.mkDefault true;

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };

  # XDG directories are useful for everyone
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}