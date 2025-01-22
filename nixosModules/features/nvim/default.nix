{ config, lib, pkgs, ... }:

with lib;
let 
  cfg = config.myNixOS.nvim;

  # Create a simple derivation for the config
  nvimConfig = pkgs.stdenv.mkDerivation {
    name = "nvim-config";
    src = ./config;

    installPhase = ''
      mkdir -p $out
      cp -r . $out/
    '';
  };

  # Create the wrapper
  nvimWrapper = pkgs.writeScriptBin "nvim" ''
    #!${pkgs.bash}/bin/bash
    if [[ ! -d /etc/neovim/site/lazy ]]; then
      mkdir -p /etc/neovim/site/lazy
      chmod -R 777 /etc/neovim/site
    fi
    NVIM_DATA_PATH=/etc/neovim/site \
    NVIM_CONFIG_PATH=/etc/neovim \
    ${pkgs.neovim}/bin/nvim \
      -u /etc/neovim/init.lua \
      --cmd "set rtp^=/etc/neovim" \
      --cmd "set rtp+=/etc/neovim/after" \
      "$@"
  '';
in {
  config = mkIf cfg.enable {
    environment = {
      systemPackages = with pkgs; [ 
        nvimWrapper
        neovim
        git # for lazy.nvim
        luajit
        ripgrep # often needed for telescope
        fd # also often needed for telescope
      ];

      variables = {
        EDITOR = "nvim";
      };
    };

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    system.activationScripts.neovimConfig = ''
      # Ensure clean slate
      rm -rf /etc/neovim
      mkdir -p /etc/neovim

      # Copy config files
      cp -r ${nvimConfig}/* /etc/neovim/

      # Ensure directories exist with proper permissions
      mkdir -p /etc/neovim/site/lazy
      chmod -R 777 /etc/neovim
    '';
  };
}
