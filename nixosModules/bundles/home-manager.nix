{
  lib,
  config,
  inputs,
  outputs,
  myLib,
  pkgs,
  ...
}: let
  cfg = config.myNixOS;
in {
  options.myNixOS = {
    userName = lib.mkOption {
      default = "emet";
      description = ''
        John Michael
      '';
    };

    userConfig = lib.mkOption {
      default = ./../../home-manager/work.nix;
      description = ''
        home-manager config path
      '';
    };

    userNixosSettings = lib.mkOption {
      default = {};
      description = ''
        NixOS user settings
      '';
    };
  };

  config = {
    programs.zsh.enable = true;

    # programs.hyprland.enable = cfg.hyprland.enable;
    # programs.hyprland.package = inputs.hyprland.packages."${pkgs.system}".hyprland;

    #  services.displayManager = lib.mkIf cfg.hyprland.enable {
    #    defaultSession = "hyprland";
    #  };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      extraSpecialArgs = {
        inherit inputs;
        inherit myLib;
        outputs = inputs.self.outputs;
      };
      users = {
        ${cfg.userName} = {...}: {
          imports = [
            (import cfg.userConfig)
            outputs.homeManagerModules.default
          ];
        };
      };
    };

    users.users.${cfg.userName} =
      {
        isNormalUser = true;
        initialPassword = "12345";
        description = cfg.userName;
        shell = pkgs.zsh;
        extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" ];
      }
      // cfg.userNixosSettings;
  };
}
