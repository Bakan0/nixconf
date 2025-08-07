{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.pipewire;
in {
  config = mkIf cfg.enable {
    # Enhanced Bluetooth with A2DP support
    hardware.bluetooth = {
      enable = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
        Policy = {
          AutoEnable = true;
        };
      };
    };

    services.blueman.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;

      # Updated Bluetooth config with A2DP priority
      wireplumber.extraConfig = {
        "50-bluez-config" = {
          "monitor.bluez.properties" = {
            "bluez5.enable-sbc-xq" = true;
            "bluez5.enable-msbc" = true;
            "bluez5.enable-hw-volume" = true;
            # Prioritize high-quality A2DP over low-quality HSP/HFP
            "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
          };
        };
      };

      # Keep noise canceling (unchanged)
      extraConfig.pipewire."99-input-denoising" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "Noise Canceling source";
              "media.name" = "Noise Canceling source";
              "filter.graph" = {
                nodes = [
                  {
                    type = "ladspa";
                    name = "rnnoise";
                    plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                    label = "noise_suppressor_mono";
                    control = {
                      "VAD Threshold (%)" = 50.0;
                      "VAD Grace Period (ms)" = 200;
                      "Retroactive VAD Grace (ms)" = 0;
                    };
                  }
                ];
              };
              "capture.props" = {
                "node.name" = "capture.rnnoise_source";
                "node.passive" = true;
                "audio.rate" = 48000;
              };
              "playback.props" = {
                "node.name" = "rnnoise_source";
                "media.class" = "Audio/Source";
                "audio.rate" = 48000;
              };
            };
          }
        ];
      };
    };
  };
}

