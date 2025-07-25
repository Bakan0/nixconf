{
  pkgs,
  config,
  lib,
  inputs,
  outputs,
  myLib,
  ...
}: let
  cfg = config.myNixOS;

  # Helper function to safely get files from a directory
  safeFilesIn = dir:
    if builtins.pathExists dir && builtins.readDir dir != {}
    then myLib.filesIn dir
    else [];

  # Taking all modules in ./features and adding enables to them
  features =
    myLib.extendModules
    (name: {
      extraOptions = {
        myNixOS.${name}.enable = lib.mkEnableOption "enable my ${name} configuration";
      };

      configExtension = config: (lib.mkIf cfg.${name}.enable config);
    })
    (safeFilesIn ./features);

  # Taking all module bundles in ./bundles and adding bundle.enables to them
  bundles =
    myLib.extendModules
    (name: {
      extraOptions = {
        myNixOS.bundles.${name}.enable = lib.mkEnableOption "enable ${name} module bundle";
      };

      configExtension = config: (lib.mkIf cfg.bundles.${name}.enable config);
    })
    (safeFilesIn ./bundles);

  # Taking all module services in ./services and adding services.enables to them
  services =
    myLib.extendModules
    (name: {
      extraOptions = {
        myNixOS.services.${name}.enable = lib.mkEnableOption "enable ${name} service";
      };

      configExtension = config: (lib.mkIf cfg.services.${name}.enable config);
    })
    (safeFilesIn ./services);

  # ADD THIS: Taking all hardware modules in ./hardware and adding hardware.enables to them
  hardware =
    myLib.extendModules
    (name: {
      extraOptions = {
        myNixOS.hardware.${name}.enable = lib.mkEnableOption "enable ${name} hardware configuration";
      };

      configExtension = config: (lib.mkIf cfg.hardware.${name}.enable config);
    })
    (safeFilesIn ./hardware);

in {
  imports =
    [
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ features
    ++ bundles
    ++ services
    ++ hardware;

  options.myNixOS = {
    hyprland.enable = lib.mkEnableOption "enable hyprland";
  };

  config = {
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      download-buffer-size = 268435456;  # 256MB
    };
    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;
  };
}

