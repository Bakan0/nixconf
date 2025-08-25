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
    # Install tflint and terraform - versions managed by NixOS packages
    home.packages = with pkgs; [
      tflint
      terraform
    ];

    # Global tflint configuration using official terraform-linters recommendations
    home.file.".tflint.hcl".text = ''
      # Require modern TFLint version (let package manager handle specific version)
      tflint {
        required_version = ">= 0.50"
      }
      
      # Configuration settings
      config {
        format = "compact"
        call_module_type = "local"
        force = false
        disabled_by_default = false
      }
      
      # Enable Terraform plugin with recommended ruleset
      plugin "terraform" {
        enabled = true
        preset  = "recommended"
      }
      
      # Azure provider plugin - let tflint auto-discover latest compatible version
      plugin "azurerm" {
        enabled = true
        source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
      }
      
      # AWS provider plugin - auto-discover version
      plugin "aws" {
        enabled = true
        source  = "github.com/terraform-linters/tflint-ruleset-aws"
      }
      
      # Essential rules for Infrastructure as Code best practices
      rule "terraform_unused_declarations" {
        enabled = true
      }
      
      rule "terraform_required_providers" {
        enabled = true
      }
      
      rule "terraform_required_version" {
        enabled = true
      }
      
      rule "terraform_naming_convention" {
        enabled = true
        format  = "snake_case"
      }
      
      rule "terraform_standard_module_structure" {
        enabled = true
      }
    '';

    # Terraform formatting configuration
    home.file.".terraformrc".text = ''
      # Terraform configuration for consistent formatting
      plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
      disable_checkpoint = true
    '';
  };
}
