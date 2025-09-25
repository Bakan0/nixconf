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

    services.xserver.enable = lib.mkIf cfg.gnome.enable true;
    services.desktopManager.gnome.enable = lib.mkIf cfg.gnome.enable true;

    # Locking GNOME requires gdm: https://github.com/NixOS/nixpkgs/issues/415677
    myNixOS.gdm.enable = lib.mkDefault (cfg.hyprland.enable || cfg.gnome.enable);

    # Set default session - prefer GNOME Wayland when both are available
    services.displayManager = lib.mkIf (cfg.hyprland.enable || cfg.gnome.enable) {
      defaultSession =
        if cfg.gnome.enable then "gnome"  # GNOME Wayland is default for "gnome"
        else if cfg.hyprland.enable then "hyprland"
        else null;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";

      extraSpecialArgs = {
        inherit inputs;
        inherit myLib;
        outputs = inputs.self.outputs;
      };

      users =
        builtins.mapAttrs (name: user: {...}: {
          imports = [
            inputs.stylix.homeManagerModules.stylix
            (import user.userConfig)
            outputs.homeManagerModules.default
          ];
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
          # Remove existing backup files to prevent conflicts
          if [ -f "/home/${name}/.config/fish/config.fish.backup" ]; then
            rm -f "/home/${name}/.config/fish/config.fish.backup"
          fi
          if [ -f "/home/${name}/.config/fish/functions/fish_prompt.fish.backup" ]; then
            rm -f "/home/${name}/.config/fish/functions/fish_prompt.fish.backup"
          fi

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
          initialPassword = "Ch4ngeM3!";
          description = "";
          shell = pkgs.fish;
          extraGroups = [ "libvirtd" "networkmanager" "wheel" "audio" "avahi" "video" ];
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
        hyprland.enable = lib.mkDefault true;  # Enable Hyprland window manager
        gnome.enable = lib.mkDefault true;     # Enable GNOME desktop environment
        kanshi.enable = true;  # Display management
        vpn.enable = true;     # VPN support

        home-users.emet = {
          userSettings = {
            description = "JM";
            extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "audio" "avahi" "video" "input" ];
            packages = with pkgs; [
              protonmail-bridge  # CLI version
            ];
          };
        };
      };

      # Only enable desktop services if desktop environments are enabled
      services.teamviewer.enable = lib.mkIf (cfg.hyprland.enable || cfg.gnome.enable) (lib.mkDefault true);
      services.protonmail-bridge.enable = lib.mkIf (cfg.hyprland.enable || cfg.gnome.enable) (lib.mkDefault true);

      # Only enable desktop services if desktop environments are enabled
      services.xserver.enable = lib.mkIf (cfg.hyprland.enable || cfg.gnome.enable) (lib.mkDefault true);
      services.desktopManager.gnome.enable = lib.mkIf cfg.gnome.enable (lib.mkDefault true);

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
          description = "Joelle";
          extraGroups = [ "networkmanager" "wheel" "audio" "video" "input" ];
          packages = with pkgs; [
            appimage-run
            signal-desktop
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
      services.desktopManager.gnome.enable = true;
      
      # Printing support
      services.printing.enable = true;
    })
  ]);
}
