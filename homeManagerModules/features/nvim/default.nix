# homeManagerModules/features/nvim/default.nix
{ config, lib, pkgs, ... }:

{
  # Remove the options declaration since it's handled by extendModules
  config = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    home.file = {
      ".config/nvim" = {
        source = ./config;
        recursive = true;
      };
    };
  };
}

