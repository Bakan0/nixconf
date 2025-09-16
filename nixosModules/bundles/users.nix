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
      user = lib.mkOption {
        type = lib.types.enum [ "emet" "joelle" ];
        description = "Which user profile to enable";
        example = "emet";
      };
    };
  };

  config = mkIf cfg.bundles.users.enable (mkMerge [
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
      backupFileExtension = null;

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

    # Clean up problematic files before Home Manager activation to prevent conflicts
    systemd.services = builtins.mapAttrs (name: user: {
      description = "Clean problematic files before Home Manager activation for ${name}";
      before = [ "home-manager-${name}.service" ];
      wantedBy = [ "home-manager-${name}.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = name;
        ExecStart = pkgs.writeShellScript "hm-pre-cleanup-${name}" ''
          # Remove files that commonly conflict with Home Manager
          rm -f /home/${name}/.config/mimeapps.list
          rm -f /home/${name}/.local/share/applications/mimeapps.list
        '';
      };
    }) (config.myNixOS.home-users);

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
    (mkIf (cfg.bundles.users.user == "emet") {
      myNixOS = {
        sysadmin = {
          enable = true;
          allowedActions = "anarchy";  # No prompts for curated admin commands
        };
        greetd.enable = true;  # Display manager for Hyprland
        kanshi.enable = true;  # Display management  
        vpn.enable = true;     # VPN support

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
    (mkIf (cfg.bundles.users.user == "joelle") {
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
  ]);
}
