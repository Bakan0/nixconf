{ pkgs, lib, config, ... }:
let
  cfg = config.myNixOS.sddm;
  sddmTheme = import ./sddm-theme.nix { inherit pkgs; };
in {
  options.myNixOS.sddm = {
    preferExternalMonitor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Prefer external monitor over laptop screen at login";
    };
    externalOutput = lib.mkOption {
      type = lib.types.str;
      default = "DP-1";
      description = "Name of external display output (DP-1, HDMI-1, etc.)";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager = {
      sddm = {
        enable = lib.mkDefault true;
        theme = "${sddmTheme}";  # Atomic-terracotta themed SDDM
        settings = lib.mkIf cfg.preferExternalMonitor {
          X11 = {
            DisplayCommand = "${pkgs.writeShellScript "sddm-display-setup" ''
              # Simple display setup - USB reset service ensures devices are ready
              if ${pkgs.xorg.xrandr}/bin/xrandr | grep -q "${cfg.externalOutput} connected"; then
                ${pkgs.xorg.xrandr}/bin/xrandr --output ${cfg.externalOutput} --auto --primary --output eDP-1 --off
              else
                # Fallback to laptop screen
                ${pkgs.xorg.xrandr}/bin/xrandr --output eDP-1 --auto --primary
              fi
            ''}";
          };
        };
      };
    };

    # Stylix will automatically theme SDDM when both are enabled

    environment.systemPackages = with pkgs; [
      libsForQt5.qt5.qtquickcontrols2
      libsForQt5.qt5.qtgraphicaleffects
    ];
  };
}

