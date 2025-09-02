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
  options.myNixOS.home-users = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        userConfig = lib.mkOption {
          default = ./../../home-manager/work.nix;
          example = "DP-1";
        };
        userSettings = lib.mkOption {
          default = {};
          example = "{}";
        };
      };
    });
    default = {};
  };

  config = {
    programs.zsh.enable = true;
    programs.fish.enable = true;

    programs.hyprland.enable = cfg.hyprland.enable;

    services.displayManager = lib.mkIf cfg.hyprland.enable {
      defaultSession = "hyprland";
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = ".backup";

      extraSpecialArgs = {
        inherit inputs;
        inherit myLib;
        outputs = inputs.self.outputs;
      };

      users =
        builtins.mapAttrs (name: user: {...}: {
          imports = [
            outputs.homeManagerModules.default
          ];
          
          # Auto-enable matching profile if it exists
          myHomeManager.profiles.${name}.enable = lib.mkDefault true;
          
          # Set username, homeDirectory and inherit stateVersion from system
          home.username = name;
          home.homeDirectory = "/home/${name}";
          home.stateVersion = config.system.stateVersion;
        })
        (config.myNixOS.home-users);
    };

    users.users = builtins.mapAttrs (
      name: user:
        {
          isNormalUser = true;
          initialPassword = "12345";
          description = "";
          shell = pkgs.fish;
          extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "audio" "video" ];
        }
        // user.userSettings
    ) (config.myNixOS.home-users);
  };
}
