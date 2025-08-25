{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let cfg = config.myHomeManager.linters;
in {
  config = mkIf cfg.enable {
    # Install shellcheck package
    home.packages = with pkgs; [
      shellcheck
    ];

    # Global shellcheck configuration using official best practices
    home.file.".shellcheckrc".text = ''
      # Look for 'source'd files relative to the checked script
      source-path=SCRIPTDIR
      
      # Allow opening any 'source'd file for normal development workflow
      external-sources=true
      
      # Enable additional checks for unquoted variables with safe values
      enable=quote-safe-variables
      
      # Enable warnings for unassigned uppercase variables  
      enable=check-unassigned-uppercase
      
      # Allow [ ! -z foo ] instead of suggesting -n (common preference)
      disable=SC2236
    '';
  };
}
