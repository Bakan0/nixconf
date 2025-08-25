{ config, lib, pkgs, inputs, ... }:
with lib;
let cfg = config.myNixOS.claude-code-latest;
in {
  config = mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        claude-code-latest = prev.claude-code.overrideAttrs (oldAttrs: rec {
          src = inputs.claude-code;
          version = "latest-${inputs.claude-code.shortRev or "unknown"}";
          
          # Ensure we're building from the git source
          preBuild = ''
            echo "Building claude-code from source: ${src}"
          '';
        });
      })
    ];
  };
}