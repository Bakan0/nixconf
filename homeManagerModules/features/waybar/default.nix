{
  pkgs,
  config,
  lib,
  ...
}: let
  scripts = import ./scripts.nix {inherit pkgs;};

  workspaces = {
    format = "{icon}";
    format-icons = {
      "1" = "⭘";  # Empty circle
      "2" = "⭘";
      "3" = "⭘";
      active = "⬤";  # Filled circle
      default = "⭘";
      urgent = "✓";  # Check mark
    };
    on-click = "activate";
  };

  mainWaybarConfig = {
    mod = "dock";
    layer = "top";
    gtk-layer-shell = true;
    height = 29;
    position = "top";

    modules-left = ["custom/logo" "hyprland/workspaces"];
    modules-right = [
      "hyprland/language"
      "network"
      "bluetooth"
      "custom/volume"
      "custom/microphone"
      "backlight"
      "custom/battery-manager"
      "clock"
      "tray"
    ];
    modules-center = ["mpris"];

    "hyprland/workspaces" = workspaces;

    bluetooth = {
      format = "󰂯";
      format-connected = "󰂱 {num_connections}";
      format-disabled = "󰂲";
      tooltip-format = "󰂯 {device_alias}";
      tooltip-format-connected = "{device_enumerate}";
      tooltip-format-enumerate-connected = "󰂱 {device_alias}";
      on-click = "blueman-manager";
    };

    backlight = {
      format = "󰃞 {percent}%";
      format-icons = ["󰃞" "󰃟" "󰃠"];
      on-scroll-up = "brightnessctl set +5%";
      on-scroll-down = "brightnessctl set 5%-";
      on-click = "brightnessctl set 50%";
      tooltip-format = "Brightness: {percent}%";
    };

    mpris = {
      format = "{player_icon} {dynamic}";
      format-paused = "{status_icon} <i>{dynamic}</i>";
      player-icons = {
        default = "󰐊";
        mpv = "󰝚";
      };
      status-icons = {
        paused = "󰏤";
      };
    };

    clock = {
      format = "󰃰 {:%A, %B %d, %Y (%H:%M:%S)}";
      format-alt = "󰥔 {:%H:%M}";
      tooltip-format = "<span size='9pt' font='WenQuanYi Zen Hei Mono'>{calendar}</span>";
      interval = 1;
      actions = {
        on-click-backward = "tz_down";
        on-click-forward = "tz_up";
        on-click-right = "mode";
        on-scroll-down = "shift_down";
        on-scroll-up = "shift_up";
      };
      calendar = {
        mode = "year";
        mode-mon-col = 3;
        on-click-right = "mode";
        on-scroll = 1;
        weeks-pos = "right";
        format = {
          days = "<span color='#ecc6d9'><b>{}</b></span>";
          months = "<span color='#ffead3'><b>{}</b></span>";
          today = "<span color='#ff6699'><b><u>{}</u></b></span>";
          weekdays = "<span color='#ffcc66'><b>{}</b></span>";
          weeks = "<span color='#99ffdd'><b>W{}</b></span>";
        };
      };
    };

    "custom/battery-manager" = {
      exec = "${scripts.waybar-battery}/bin/waybar-battery status";
      return-type = "json";
      interval = 30;
      on-click = "${scripts.waybar-battery}/bin/waybar-battery force";
      on-click-middle = "${scripts.waybar-battery}/bin/waybar-battery restore";
      on-click-right = "${scripts.waybar-battery}/bin/waybar-battery status-popup";
      tooltip = true;
      format = "{}";
    };

    "custom/gpu-usage" = {
      exec = "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits";
      format = "󰢮 {}";
      interval = 10;
    };

    "custom/logo" = {
      exec = "echo '❄️'";
      format = "{}";
    };

    "hyprland/window" = {
      format = "󱂬  {}";
      rewrite = {
        "(.*) — Mozilla Firefox" = "$1 󰈹";
        "(.*)Steam" = "Steam 󰓓";
      };
      separate-outputs = true;
    };

    "hyprland/language" = {
      format = "󰌌 {}";
      format-en = "english";
    };

    network = {
      format-disconnected = "󰤮 Disconnected";
      format-ethernet = "󰤪 Wired";
      format-linked = "󰤪 {ifname} (No IP)";
      format-wifi = "󰤨 {essid}";
      interval = 5;
      max-length = 30;
      tooltip-format = "󰤪 {ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
    };

  # Modern PipeWire volume widget
  "custom/volume" = {
    format = "{}";
    exec = "${scripts.waybar-volume}/bin/waybar-volume";
    on-click = "${scripts.waybar-volume-toggle}/bin/waybar-volume-toggle";
    on-click-middle = "pavucontrol";
    on-click-right = "${scripts.waybar-volume-cycle}/bin/waybar-volume-cycle";  # ← NEW
    on-scroll-up = "${scripts.waybar-volume-up}/bin/waybar-volume-up";
    on-scroll-down = "${scripts.waybar-volume-down}/bin/waybar-volume-down";
    interval = 1;
    tooltip-format = "Volume | Left: Toggle mute | Middle: Settings | Right: Cycle outputs | Scroll: Adjust";
  };
  
  # Modern PipeWire microphone widget
  "custom/microphone" = {
    format = "{}";
    exec = "${scripts.waybar-microphone}/bin/waybar-microphone";
    on-click = "${scripts.waybar-microphone-toggle}/bin/waybar-microphone-toggle";
    on-click-middle = "pavucontrol";  # ← CHANGED from cycle to pavucontrol
    on-click-right = "${scripts.waybar-microphone-cycle}/bin/waybar-microphone-cycle";  # ← MOVED here
    on-scroll-up = "${scripts.waybar-microphone-volume-up}/bin/waybar-microphone-volume-up";
    on-scroll-down = "${scripts.waybar-microphone-volume-down}/bin/waybar-microphone-volume-down";
    interval = 2;
    tooltip-format = "Microphone | Left: Toggle mute | Middle: Settings | Right: Cycle sources | Scroll: Adjust volume";
  };

    tray = {
      icon-size = 15;
      spacing = 5;
    };
  };

  # Better CSS with actual stylix colors instead of @base00 variables
  css = ''
    * {
        border: none;
        border-radius: 0px;
        font-family: "${config.stylix.fonts.monospace.name}";
        font-weight: bold;
        font-size: 14px;
        min-height: 0px;
    }

    window#waybar {
        background: #${config.stylix.base16Scheme.base00};
        color: #${config.stylix.base16Scheme.base05};
    }

    tooltip {
        background: #${config.stylix.base16Scheme.base01};
        color: #${config.stylix.base16Scheme.base05};
        border-radius: 10px;
        border-width: 1px;
        border-style: solid;
        border-color: #${config.stylix.base16Scheme.base03};
    }

    #workspaces button {
        margin: 0 4px;
        padding: 0 4px;
        min-width: 24px;
        color: #${config.stylix.base16Scheme.base05};
        background: #${config.stylix.base16Scheme.base01};
    }

    #workspaces button.active {
        background: #${config.stylix.base16Scheme.base0D};
        color: #${config.stylix.base16Scheme.base00};
        border-radius: 7px;
    }

    #workspaces button:hover {
        background: #${config.stylix.base16Scheme.base02};
    }

    #cpu,
    #memory,
    #custom-power,
    #clock,
    #workspaces,
    #window,
    #custom-updates,
    #network,
    #bluetooth,
    #custom-volume,
    #custom-microphone,
    #custom-wallchange,
    #custom-mode,
    #tray {
        color: #${config.stylix.base16Scheme.base05};
        background: #${config.stylix.base16Scheme.base01};
        opacity: 1;
        padding: 0px;
        margin: 3px 3px 3px 3px;
    }

    #custom-battery {
        color: #${config.stylix.base16Scheme.base0B};
    }

    #clock {
        color: #${config.stylix.base16Scheme.base0A};
        padding-left: 12px;
        padding-right: 12px;
    }

    #network {
        color: #${config.stylix.base16Scheme.base0E};
        padding-left: 4px;
        padding-right: 4px;
    }

    #language {
        color: #${config.stylix.base16Scheme.base09};
        padding-left: 9px;
        padding-right: 9px;
    }

    #bluetooth {
        color: #${config.stylix.base16Scheme.base0D};
        padding-left: 4px;
        padding-right: 0px;
    }

    #backlight {
      color: #${config.stylix.base16Scheme.base0A};
      padding-left: 4px;
      padding-right: 4px;
    }

    #custom-volume {
        color: #${config.stylix.base16Scheme.base0E};
        padding-left: 4px;
        padding-right: 4px;
    }

    #custom-microphone {
        color: #${config.stylix.base16Scheme.base08};
        padding-left: 2px;
        padding-right: 4px;
        font-weight: bold;
    }

    #custom-logo {
        margin-left: 6px;
        padding-right: 4px;
        color: #${config.stylix.base16Scheme.base0D};
        font-size: 16px;
    }

    #tray {
        padding-left: 4px;
        padding-right: 4px;
    }
  '';

in {
  home.packages = [
    scripts.waybar-battery 
    scripts.waybar-volume
    scripts.waybar-volume-toggle
    scripts.waybar-volume-up
    scripts.waybar-volume-down
    scripts.waybar-volume-cycle
    scripts.waybar-microphone 
    scripts.waybar-microphone-toggle 
    scripts.waybar-microphone-volume-up 
    scripts.waybar-microphone-volume-down
    scripts.waybar-microphone-cycle
  ];

  programs.waybar = {
    enable = true;
    package = (pkgs.waybar.override {
      withMediaPlayer = true;
    }).overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
    });
    systemd = {
      enable = true;
      target = "graphical-session.target";
    };
    style = css;
    settings = {mainBar = mainWaybarConfig;};
  };

}

