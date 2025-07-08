{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  moveToMonitor =
    lib.mapAttrsToList
    (
      id: workspace: "hyprctl dispatch moveworkspacetomonitor ${id} ${toString workspace.monitorId}"
    )
    config.myHomeManager.workspaces;

  moveToMonitorScript = pkgs.writeShellScriptBin "script" ''
    ${lib.concatLines moveToMonitor}
  '';

  generalStartScript = pkgs.writeShellScriptBin "start" ''
    ${pkgs.swww}/bin/swww init &

    ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator &

    # hyprctl setcursor Bibata-Modern-Ice 16 &

    systemctl --user import-environment PATH &
    systemctl --user restart xdg-desktop-portal.service &


    # wait a tiny bit for wallpaper
    sleep 2


    ${pkgs.swww}/bin/swww img ${config.stylix.image} &

    # wait for monitors to connect
    sleep 3

    ${lib.getExe moveToMonitorScript}

    # general startupScript extension
    ${config.myHomeManager.startupScript}
  '';

  autostarts =
    lib.lists.flatten
    (lib.mapAttrsToList
      (
        id: workspace: (map (startentry: "[workspace ${id} silent] ${startentry}") workspace.autostart)
      )
      config.myHomeManager.workspaces);

  monitorScript = pkgs.writeShellScriptBin "script" ''
    handle() {
      case $1 in monitoradded*)
        ${lib.getExe moveToMonitorScript}
      esac
    }

    ${lib.getExe pkgs.socat} - "UNIX-CONNECT:/tmp/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock" | while read -r line; do handle "$line"; done
  '';
  exec-once =
    [
      (lib.getExe generalStartScript)
      (lib.getExe monitorScript)

      # I forgor why i need this
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    ]
    ++ autostarts;
in {
  imports = [
    ./monitors.nix
    ./xdph.nix
  ];

  options = {
    myHomeManager.windowanimation = lib.mkOption {
      default = "workspaces, 1, 3, myBezier, fade";
      description = ''
        animation for switching workspaces.
        I don't like having slide on my ultrawide monitor
      '';
    };
  };

  config = {
    myHomeManager.waybar.enable = lib.mkDefault true;
    myHomeManager.keymap.enable = lib.mkDefault true;

    wayland.windowManager.hyprland = {
      plugins = [
        # inputs.hyprscroller.packages.${pkgs.system}.hyprscroller
      ];
      # package = inputs.hyprland.packages."${pkgs.system}".hyprland;

      enable = true;
      settings = {
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          #  "col.active_border" = lib.mkForce "rgba(${config.stylix.base16Scheme.base0E}ff) rgba(${config.stylix.base16Scheme.base09}ff) 60deg";
          #  "col.inactive_border" = lib.mkForce "rgba(${config.stylix.base16Scheme.base00}ff)";

          layout = "dwindle";
        };

        monitor =
          lib.mapAttrsToList
          (
            name: m: let
              resolution = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
              position = "${toString m.x}x${toString m.y}";
            in "${name},${
              if m.enabled
              then "${resolution},${position},1"
              else "disable"
            }"
          )
          (config.myHomeManager.monitors);

        # workspace =
        #   lib.mapAttrsToList
        #   (
        #     name: m: "${m.name},${m.workspace}"
        #   )
        #   (lib.filter (m: m.enabled && m.workspace != null) config.myHomeManager.monitors);

        env = [
          "XCURSOR_SIZE,24"
        ];

        input = {
          kb_layout = "us";
          kb_variant = "";
          kb_model = "";
          kb_options = "";

          kb_rules = "";

          follow_mouse = 1;

          touchpad = {
            natural_scroll = true;
          };

          natural_scroll = true;

          repeat_rate = 40;
          repeat_delay = 250;
          force_no_accel = true;

          sensitivity = 0.0; # -1.0 - 1.0, 0 means no modification.
        };

        misc = {
          enable_swallow = true;
          force_default_wallpaper = 0;

          # swallow_regex = "^(Alacritty|wezterm)$";
        };

        binds = {
          movefocus_cycles_fullscreen = 0;
        };

        decoration = lib.mkForce {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          rounding = 5;
          shadow = {
            enabled = true;
            range = 30;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
        };
        
        animations = {
          enabled = true;
        
          bezier = "myBezier, 0.25, 0.9, 0.1, 1.02";
        
          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
          ] ++ [config.myHomeManager.windowanimation];
        };
        
          dwindle = {
            pseudotile = true;
            preserve_split = true;
            # Remove this line as it's deprecated:
            # no_gaps_when_only = true;
            force_split = 2;
          };
           
        master = {
          # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
          # new_is_master = true;
          # orientation = "center";
        };

        gestures = {
          # See https://wiki.hyprland.org/Configuring/Variables/ for more
          workspace_swipe = false;
        };
        "$mainMod" = "SUPER";

        # "$mainMod" =
        #   if (osConfig.altIsSuper or false)
        #   then "ALT"
        #   else "SUPER";

        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        bind =
          [
            "$mainMod, return, exec, kitty"
            "$mainMod, Q, killactive,"
            "$mainMod SHIFT, M, exit,"
            "$mainMod SHIFT, F, togglefloating,"
            "$mainMod, F, fullscreen,"
            "$mainMod, P, exec, toggle-laptop-display"
            "$mainMod, T, pin,"
            "$mainMod, G, togglegroup,"
            "$mainMod, bracketleft, changegroupactive, b"
            "$mainMod, bracketright, changegroupactive, f"
            "$mainMod, backslash, moveoutofgroup"
            "$mainMod, S, exec, rofi -show drun -show-icons"
            "$mainMod, P, pin, active"
            "$mainMod, Escape, exec, hyprlock"

            ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
            ",XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"

            "$mainMod, left, movefocus, l"
            "$mainMod, right, movefocus, r"
            "$mainMod, up, movefocus, u"
            "$mainMod, down, movefocus, d"

            "$mainMod, h, movefocus, l"
            "$mainMod, l, movefocus, r"
            "$mainMod, k, movefocus, u"
            "$mainMod, j, movefocus, d"

            "$mainMod SHIFT, h, movewindow, l"
            "$mainMod SHIFT, l, movewindow, r"
            "$mainMod SHIFT, k, movewindow, u"
            "$mainMod SHIFT, j, movewindow, d"

            "$mainMod ALT, h, movewindoworgroup, l"
            "$mainMod ALT, l, movewindoworgroup, r"
            "$mainMod ALT, k, movewindoworgroup, u"
            "$mainMod ALT, j, movewindoworgroup, d"

          ]
          ++ map (n: "$mainMod SHIFT, ${toString n}, movetoworkspace, ${toString (
            if n == 0
            then 10
            else n
          )}") [1 2 3 4 5 6 7 8 9 0]
          ++ map (n: "$mainMod, ${toString n}, workspace, ${toString (
            if n == 0
            then 10
            else n
          )}") [1 2 3 4 5 6 7 8 9 0];

        binde = [
          "$mainMod SHIFT, h, moveactive, -20 0"
          "$mainMod SHIFT, l, moveactive, 20 0"
          "$mainMod SHIFT, k, moveactive, 0 -20"
          "$mainMod SHIFT, j, moveactive, 0 20"

          "$mainMod CTRL, l, resizeactive, 30 0"
          "$mainMod CTRL, h, resizeactive, -30 0"
          "$mainMod CTRL, k, resizeactive, 0 -10"
          "$mainMod CTRL, j, resizeactive, 0 10"
        ];

        bindm = [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # league of legends fixes
        # windowrulev2 = [
        #   "float,class:^(leagueclientux.exe)$,title:^(League of Legends)$"
        #   "tile,class:^(league of legends.exe)$,title:^(League of Legends (TM) Client)$ windowrule = size 1920 1080,^(league of legends.exe)$"
        # ];
        #
        # windowrule = [
        #   "size 1600 900,^(leagueclientux.exe)$"
        #   "center,^(leagueclientux.exe)$"
        #   "center,^(league of legends.exe)$"
        #   "forceinput,^(league of legends.exe)$"
        # ];

        windowrulev2 = [
          "float,class:^(Vivaldi-stable)$,title:^(Bitwarden - Vivaldi)$"
        ];

        exec-once = exec-once;
      };
    };

    home.packages = with pkgs; [
      grim
      slurp
      wl-clipboard

      swww

      networkmanagerapplet
      blueman
      rofi-wayland

      hypridle
      hyprlock
      procps
    ];
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          before_sleep_cmd = "hyprlock";
          ignore_dbus_inhibit = false;
          lock_cmd = "pidof hyprlock || hyprlock";
        };
    
        listener = [
          {
            timeout = 1200;  # 20 minutes
            on-timeout = "hyprlock";
          }
          {
            timeout = 1500;  # 25 minutes  
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 2700; # 45 minutes
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
    systemd.user.services.lock-on-suspend = {
      Unit = {
        Description = "Lock screen before suspend";
        Before = [ "sleep.target" ];
      };
      Install.WantedBy = [ "sleep.target" ];
      Service = {
        Type = "forking";
        ExecStart = "${pkgs.hyprlock}/bin/hyprlock";
        TimeoutSec = 5;
      };
    };
    systemd.user.services.qbittorrent-suspend-inhibitor = {
      Unit = {
        Description = "Prevent system suspension when qbittorrent is running";
        After = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "simple";
        Restart = "always";
        RestartSec = 30;
        ExecStart = pkgs.writeShellScript "qbt-inhibitor" ''
          LOCK_FILE="$XDG_RUNTIME_DIR/qbt-inhibitor.lock"
          INHIBITOR_PID=""
    
          cleanup() {
            if [ -n "$INHIBITOR_PID" ] && kill -0 "$INHIBITOR_PID" 2>/dev/null; then
              echo "Cleaning up inhibitor lock (PID: $INHIBITOR_PID)"
              kill "$INHIBITOR_PID" 2>/dev/null || true
            fi
            rm -f "$LOCK_FILE"
            exit 0
          }
    
          trap cleanup EXIT TERM INT
    
          while true; do
            if ${pkgs.procps}/bin/pgrep -f qbittorrent >/dev/null 2>&1; then
              if [ ! -f "$LOCK_FILE" ]; then
                echo "qbittorrent detected - creating suspension inhibitor lock"
                ${pkgs.systemd}/bin/systemd-inhibit --what=sleep --who="qbittorrent-monitor" --why="qbittorrent is running" --mode=block sleep infinity &
                INHIBITOR_PID=$!
                echo "$INHIBITOR_PID" > "$LOCK_FILE"
              fi
            else
              if [ -f "$LOCK_FILE" ]; then
                echo "qbittorrent not running - removing suspension inhibitor lock"
                INHIBITOR_PID=$(cat "$LOCK_FILE" 2>/dev/null)
                if [ -n "$INHIBITOR_PID" ]; then
                  kill "$INHIBITOR_PID" 2>/dev/null || true
                fi
                rm -f "$LOCK_FILE"
                INHIBITOR_PID=""
              fi
            fi
            sleep 30
          done
        '';
      };
    };
  };
}
