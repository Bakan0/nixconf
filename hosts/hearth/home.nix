{ config, lib, pkgs, inputs, ... }:

{
  myHomeManager = {
    bundles.general.enable = true;
    bundles.databender.enable = true;  # Azure/PowerShell work tools
    
    # Hearth-specific customizations
    # Terracotta/atomic theme preferences will be handled by stylix
  };
  
  # Home-specific packages and configurations can go here
  home.packages = with pkgs; [
    # Additional packages specific to hearth setup
  ];
}