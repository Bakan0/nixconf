{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myHomeManager.claude-code-latest;
  
  claude-code-latest = 
    let
      registryInfo = builtins.fromJSON (builtins.readFile (pkgs.fetchurl {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/";
        sha256 = "sha256-n4luKvnTi/vOgzbXr+5Zg7v1BeeQPaoFNA0BZ9isX0I=";
      }));
      latestVersion = registryInfo.dist-tags.latest;
    in
    pkgs.claude-code.overrideAttrs (oldAttrs: rec {
      version = latestVersion;
      src = pkgs.fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${latestVersion}.tgz";
        hash = "sha256-dI3nnuN5a8lBsuTVGzEASxqxCKr2KrTpBdEIgk/47Kw=";
      };
      npmDepsHash = lib.fakeHash; # Need to override this too for new version
    });
in {
  config = mkIf cfg.enable {
    home.packages = [ claude-code-latest ];
  };
}