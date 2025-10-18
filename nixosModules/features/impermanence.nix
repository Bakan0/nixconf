{
  pkgs,
  lib,
  inputs,
  config,
  myLib,
  ...
}: let
  cfg = config.myNixOS.impermanence;
  cfg' = config;
in {
  imports = [
    inputs.impermanence.nixosModules.impermanence
    (myLib.extendModule {
      # path to module
      path = inputs.persist-retro.nixosModules.persist-retro;

      # adding an enable option
      extraOptions = {
        extended.persist-retro.enable = lib.mkEnableOption "enable persist-retro";
      };

      # only enabling the module if this option is set to true
      configExtension = config: lib.mkIf cfg'.extended.persist-retro.enable config;
    })
  ];

  options.myNixOS.impermanence = {
    directories = lib.mkOption {
      default = [];
      description = ''
        Additional system directories to persist beyond defaults
      '';
    };
    files = lib.mkOption {
      default = [];
      description = ''
        Additional system files to persist beyond defaults
      '';
    };
  };

  # Module content (wrapped by extendModules automatically)
  # NOTE: /persist/system structure for system-level persistence
  # User-level persistence handled in homeManagerModules/features/impermanence.nix

  fileSystems."/persist".neededForBoot = true;
  programs.fuse.userAllowOther = true;

  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories =
      [
        "/etc/nixos"
        "/var/log"
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
        "/var/lib/sbctl"  # Secure Boot keys
      ]
      ++ (lib.optionals config.services.colord.enable [{
        directory = "/var/lib/colord";
        user = "colord";
        group = "colord";
        mode = "u=rwx,g=rx,o=";
      }])
      ++ cfg.directories;
    files = [
      "/etc/machine-id"
    ] ++ cfg.files;
  };

  # Optional: Enable persist-retro for interactive management
  extended.persist-retro.enable = lib.mkDefault false;
}
