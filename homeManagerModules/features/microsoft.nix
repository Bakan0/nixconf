{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myHomeManager.microsoft;
in {
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # Microsoft Edge browser for GCCH environments
      microsoft-edge
      
      # Azure CLI with extensions for cloud architecture work
      (azure-cli.overrideAttrs (oldAttrs: {
        doInstallCheck = false;  # Skip tests for faster builds
      }))
      azure-cli-extensions.azure-firewall
      # azure-cli-extensions.costmanagement
      azure-cli-extensions.fzf
      # azure-cli-extensions.ip-group
      # azure-cli-extensions.mdp
      # azure-cli-extensions.multicloud-connector
      # azure-cli-extensions.subscription
      # azure-cli-extensions.virtual-network-manager
      # azure-cli-extensions.virtual-wan
      
      # PowerShell for Azure automation
      powershell
    ];

    # Enable PowerShell linting support
    myHomeManager.linters.powershell.enable = mkDefault true;
  };
}