{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: let
  cfg = config.myHomeManager.impermanence;
in {
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  options.myHomeManager.impermanence = {
    directories = lib.mkOption {
      default = [];
      description = ''
        Additional directories to persist beyond defaults
      '';
    };
    files = lib.mkOption {
      default = [];
      description = ''
        Additional files to persist beyond defaults
      '';
    };
    cache = {
      directories = lib.mkOption {
        default = [];
        description = ''
          Cache directories to persist
        '';
      };
      files = lib.mkOption {
        default = [];
        description = ''
          Cache files to persist
        '';
      };
    };
  };

  # Module content (wrapped by extendModules automatically)
  # Persists user data to /persist/home/<username>

  home.persistence."/persist/home/${config.home.username}" = {
    directories =
      [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        ".gnupg"
        ".ssh"
        ".local/share/keyrings"
        ".local/share/direnv"
        "nixconf"
      ]
      ++ cfg.directories;
    files = [
    ] ++ cfg.files;
    allowOther = true;
  };

  # Cache persistence - separate from main persistence
  home.persistence."/persist/cache/${config.home.username}" = {
    directories = cfg.cache.directories;
    files = cfg.cache.files;
    allowOther = true;
  };
}
