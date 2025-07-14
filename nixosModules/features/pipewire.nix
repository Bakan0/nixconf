{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.pipewire;
in {
  config = mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      wireplumber = {
        enable = true;
        extraConfig = {
          "50-alsa-config" = {
            "monitor.alsa.rules" = [
              {
                matches = [
                  { "device.name" = "alsa_card.pci-0000_00_1f.3"; }
                ];
                actions = {
                  update-props = {
                    "device.profile" = "HiFi";
                  };
                };
              }
            ];
          };
        };
      };

      # Noise canceling configuration using new extraConfig format
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

      # Force ALSA capture source creation
#      extraConfig.pipewire."99-force-alsa-capture" = {
#        "context.modules" = [
#          {
#            args = {
#              "alsa.card" = "0";
#              "alsa.device" = "0";
#              "alsa.subdevice" = "0";
#              "alsa.stream" = "capture";
#              "audio.channels" = "2";
#              "audio.rate" = "44100";
#              "audio.format" = "S16LE";
#              "node.name" = "alsa-capture-internal";
#              "media.class" = "Audio/Source";
#              "node.description" = "Internal Microphone";
#            };
#          }
#        ];
#      };
    };
  };
}

