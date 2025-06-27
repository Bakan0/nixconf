{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
with pkgs; let
  inherit (lib) getExe mkIf mkOption mkDefault;
  cfg = config.myHomeManager.keymap;
in {
  options = {

    myHomeManager.keymap.keybinds = mkOption {
      default = {
        # DIRECT APP BINDINGS
        "$mainMod, A" = {
          exec = "vivaldi";  # Super+A opens Vivaldi
        };

        "$mainMod, B" = {
          exec = "pcmanfm";  # Super+B opens file manager
        };

        # APP LAUNCHER SUBMAP (your existing Super+D system)
        "$mainMod, D" = {
          "f".package = firefox;
          "t".package = telegram-desktop;
          "s".package = pavucontrol;
          "b".package = rofi-bluetooth;
          "h".script = ''
            ${getExe kitty} -e ${getExe btop}
          '';
          "c".script = ''
            ${getExe kitty} -e ${getExe libqalculate}
          '';
        };

        # MEDIA CONTROLS
        "$mainMod, O".script = ''
          ${getExe playerctl} play-pause
        '';

        "XF86AudioPlay" = {
          script = "playerctl play-pause";
        };

        "XF86AudioNext" = {
          script = "playerctl next";
        };

        "XF86AudioPrev" = {
          script = "playerctl previous";
        };

        # VOLUME CONTROLS
        "XF86AudioRaiseVolume" = {
          script = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+";
        };

        "XF86AudioLowerVolume" = {
          script = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-";
        };

        "XF86AudioMute" = {
          script = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };

        "XF86AudioMicMute" = {
          script = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        };

        # MICROPHONE TOGGLE (your existing Super+V)
        "$mainMod, V".script = ''
          ${pkgs.alsa-utils}/bin/amixer sset Capture toggle
        '';

        # BRIGHTNESS CONTROLS
        "XF86MonBrightnessUp" = {
          script = "brightnessctl set +5%";
        };

        "XF86MonBrightnessDown" = {
          script = "brightnessctl set 5%-";
        };

        # SCREENSHOT TOOLS
        "SUPERCONTROL, S".script = ''
          ${getExe grim} -l 0 - | ${wl-clipboard}/bin/wl-copy
        '';

        "SUPERSHIFT, E".script = ''
          ${wl-clipboard}/bin/wl-paste | ${getExe swappy} -f -
        '';

        "SUPERSHIFT, S".script = ''
          ${getExe grim} -g "$(${getExe slurp} -w 0)" - \
          | ${wl-clipboard}/bin/wl-copy
        '';

        # SCREEN RECORDING
        "$mainMod, F1"."$mainMod, F1".script = ''
          mkdir -p "$HOME/Videos/recorded"
          echo 1 > /tmp/recording-value
          if ! ${getExe gpu-screen-recorder} -w screen -f 60 -c mp4 -r 450 -o "$HOME/Videos/recorded"; then
            notify-send "Screen recording failed"
            echo 0 > /tmp/recording-value
            exit 1
          fi
        '';

        "$mainMod, F2".script = ''
          ${getExe killall} -SIGUSR1 gpu-screen-recorder
          notify-send "screen recording saved"
        '';

        "$mainMod, F3".script = ''
          ${getExe killall} -SIGINT gpu-screen-recorder
          echo 0 > /tmp/recording-value
          notify-send "screen recording stopped"
        '';

        # EXAMPLE: Hierarchical binding
        "$mainMod, M" = {
          "v" = {
            exec = "vivaldi";    # Super+M, then v = Vivaldi
          };
          "f" = {
            exec = "pcmanfm";    # Super+M, then f = File manager
          };
          "t" = {
            exec = "kitty";      # Super+M, then t = Terminal
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # HYPRLAND-SPECIFIC CONFIG (only when Hyprland is enabled)
    wayland.windowManager.hyprland = mkIf config.wayland.windowManager.hyprland.enable (let
      wrapWriteApplication = text:
        lib.getExe (pkgs.writeShellApplication {
          name = "script";
          text = text;
        });

      makeHyprBinds = parentKeyName: keyName: keyOptions: let
        newKeyName =
          if builtins.match ".*,.*" keyName != null
          then keyName
          else "," + keyName;
        submapname =
          parentKeyName
          + (builtins.replaceStrings [" " "," "$"] ["hypr" "submaps" "suck"] newKeyName);
      in
        # DIRECT EXECUTION - script
        if builtins.hasAttr "script" keyOptions
        then ''
          bind = ${newKeyName}, exec, ${wrapWriteApplication keyOptions.script}
        ''
        # DIRECT EXECUTION - exec command
        else if builtins.hasAttr "exec" keyOptions
        then ''
          bind = ${newKeyName}, exec, ${keyOptions.exec}
        ''
        # DIRECT EXECUTION - package
        else if builtins.hasAttr "package" keyOptions
        then ''
          bind = ${newKeyName}, exec, ${lib.getExe keyOptions.package}
        ''
        # HIERARCHICAL SUBMAPS
        else ''
          bind = ${newKeyName}, submap, ${submapname}

          submap = ${submapname}
          ${lib.concatLines (lib.mapAttrsToList (makeHyprBinds submapname) keyOptions)}
          bind = , escape, submap, reset
          submap = reset
        '';
    in {
      extraConfig =
        lib.mkAfter
        (lib.concatLines
          (lib.mapAttrsToList
            (makeHyprBinds "root")
            cfg.keybinds));
    });
  };
}

