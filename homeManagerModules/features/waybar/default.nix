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
    height = 26;
    position = "top";

    modules-left = ["custom/logo" "hyprland/workspaces"];
    modules-right = [
      "hyprland/language"
      "network"
      "bluetooth"
      "pulseaudio"
      "pulseaudio#microphone"
      "backlight"
      "custom/battery-manager"
      "clock"
      "tray"
    ];
    modules-center = ["mpris"];

    "wlr/workspaces" = workspaces;
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
      on-click = "brightnessctl set 50%";  # Click to set to 50%
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
      format = "󰃰 {:%A, %B %d, %Y (%R)}";
      format-alt = "󰥔 {:%H:%M}";
      tooltip-format = "<span size='9pt' font='WenQuanYi Zen Hei Mono'>{calendar}</span>";
    };


    "custom/battery-manager" = {
      exec = "${scripts.waybar-battery}/bin/waybar-battery status";
      return-type = "json";
      interval = 30;
      on-click = "${scripts.waybar-battery}/bin/waybar-battery force";           # Left click = Force charge
      on-click-middle = "${scripts.waybar-battery}/bin/waybar-battery restore";  # Middle click = Restore defaults  
      on-click-right = "${scripts.waybar-battery}/bin/waybar-battery status-popup"; # Right click = Show status
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
      format-uk = "державна";
      format-en = "english";
      format-ru = "русский";
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

    "pulseaudio" = {
      format = "{volume}% {icon}";
      format-muted = "{volume}% 󰖁";  # Show volume percentage even when muted
      format-icons = {
        headphone = "󰋋";
        headset = "󰋎";
        default = ["󰕿" "󰖀" "󰕾"];
      };
      on-click = "pamixer --toggle-mute";
      on-click-middle = "pavucontrol";
      tooltip = true;
      tooltip-format = "Volume: {volume}% | Left: Toggle mute | Middle: Settings";
    };


    "pulseaudio#microphone" = {
      format = "{format_source}";
      format-source = "󰍬 {volume}%";
      format-source-muted = "󰍭 Muted";
      on-click = "pamixer --default-source --toggle-mute";
      on-click-middle = "pavucontrol -t 4";
      on-click-right = "wpctl set-default $(wpctl status | awk '/Sources:/{flag=1;next} /Sinks:|Filters:|Streams:/{flag=0} flag && /^[[:space:]]*[0-9]+\./ && !/\\*/ {print $1; exit}' | tr -d '.')";
      tooltip = true;
      tooltip-format = "Microphone: {volume}% | Left: Toggle mute | Middle: Settings | Right: Switch input";
    };
   
    tray = {
      icon-size = 15;
      spacing = 5;
    };
  };

  css = ''
    * {
        border: none;
        border-radius: 0px;
        font-family: "JetBrainsMono Nerd Font Mono";
        font-weight: bold;
        font-size: 14px;
        min-height: 0px;
    }

    window#waybar {
        background: @base00;
        color: @base05;
    }

    tooltip {
        background: @base01;
        color: @base05;
        border-radius: 10px;
        border-width: 1px;
        border-style: solid;
        border-color: @base03;
    }

    #workspaces button {
        margin: 0 4px;
        padding: 0 4px;
        min-width: 24px;
        color: @base05;
        background: @base01;
    }

    #workspaces button.active {
        background: @base0D;
        color: @base00;
        border-radius: 7px;
    }

    #workspaces button:hover {
        background: @base02;
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
    #pulseaudio,
    #pulseaudio-microphone,
    #custom-wallchange,
    #custom-mode,
    #tray {
        color: @base05;
        background: @base01;
        opacity: 1;
        padding: 0px;
        margin: 3px 3px 3px 3px;
    }

    #custom-battery {
        color: @base0B;
    }

    #clock {
        color: @base0A;
        padding-left: 12px;
        padding-right: 12px;
    }

    #network {
        color: @base0E;
        padding-left: 4px;
        padding-right: 4px;
    }

    #language {
        color: @base09;
        padding-left: 9px;
        padding-right: 9px;
    }

    #bluetooth {
        color: @base0D;
        padding-left: 4px;
        padding-right: 0px;
    }

    #backlight {
      color: @base0A;  /* Using yellow like your clock */
      padding-left: 4px;
      padding-right: 4px;
    }
  
    #pulseaudio {
        color: @base0E;
        padding-left: 4px;
        padding-right: 4px;
    }

    #pulseaudio-microphone {
        color: @base08;
        padding-left: 0px;
        padding-right: 4px;
    }

    #custom-logo {
        margin-left: 6px;
        padding-right: 4px;
        color: @base0D;
        font-size: 16px;
    }

    #tray {
        padding-left: 4px;
        padding-right: 4px;
    }
  '';
in {
  home.packages = [scripts.waybar-battery ];

  programs.waybar = {
    enable = true;
    package = (pkgs.waybar.override {
      withMediaPlayer = true;
    }).overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
    });
    systemd.enable = true;
    style = css;
    settings = {mainBar = mainWaybarConfig;};
  };
}
