{
  lib,
  config,
  inputs,
  outputs,
  myLib,
  pkgs,
  ...
}: 
with lib;
let
  cfg = config.myNixOS;
in {
  options.myNixOS = {
    home-users = lib.mkOption {
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

    bundles.users = {
      emet = {
        enable = lib.mkEnableOption "emet user profile with SSH keys and admin settings";
      };
      joelle = {
        enable = lib.mkEnableOption "joelle user profile";
      };
    };
  };

  config = mkMerge [
    {
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
    }

    # Emet user profile
    (mkIf cfg.bundles.users.emet.enable {
      myNixOS = {
        sysadmin = {
          enable = true;
          allowedActions = "anarchy";  # No prompts for curated admin commands
        };
        greetd.enable = true;  # Display manager for Hyprland
        kanshi.enable = true;  # Display management  
        tpm2.enable = true;    # TPM2 support for LUKS auto-unlock
        vpn.enable = true;     # VPN support
        virtualisation.enable = lib.mkDefault false;

        home-users.emet = {
          userSettings = {
            extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "audio" "avahi" "video" ];
          };
        };
      };

      users.users = {
        root.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
        ];
        emet.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
        ];
      };
    })

    # Joelle user profile  
    (mkIf cfg.bundles.users.joelle.enable {
      myNixOS.home-users.joelle = {
        userSettings = {
          extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
          packages = with pkgs; [
            appimage-run
            kitty
            signal-desktop
            tree
            yazi
          ];
        };
      };

      # Joelle's SSH keys
      users.users.joelle.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
      ];

      # GNOME desktop environment (joelle's preference)  
      services.xserver.enable = true;
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;
      
      # Printing support
      services.printing.enable = true;
    })
  ];
}
