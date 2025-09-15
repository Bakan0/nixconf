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

      # Microsoft workspace launcher
      (writeShellScriptBin "microsoft" ''
        set -euo pipefail
        
        show_help() {
            echo "Usage: microsoft [--help] [--work] [--admin] [--all]"
            echo "Launch Microsoft applications for productivity workflows"
            echo ""
            echo "Options:"
            echo "  --work    Launch standard work profile (2 PWAs + normal profile)"
            echo "  --admin   Launch admin profile only"
            echo "  --all     Launch everything (2 PWAs + admin profile)"
            echo "  --help    Show this help message"
            echo ""
            echo "Default: Launches work profile if no options specified"
        }

        launch_work_profile() {
            echo "🚀 Starting Microsoft work environment..."
            
            # Launch Teams PWA
            echo "  Starting Teams PWA..."
            microsoft-edge --app=https://gov.teams.microsoft.us/v2 &
            
            # Launch Outlook PWA  
            echo "  Starting Outlook PWA..."
            microsoft-edge --app=https://outlook.office365.us/ &
            
            echo "✅ Microsoft work environment started!"
            echo "   - Teams PWA"
            echo "   - Outlook PWA"
        }

        launch_admin_profile() {
            echo "🛡️  Starting Microsoft admin environment..."
            
            # Launch Microsoft Edge with admin profile
            echo "  Starting Edge admin profile..."
            microsoft-edge --profile-directory="Profile 1" &
            
            echo "✅ Microsoft admin environment started!"
            echo "   - Edge admin profile"
        }

        launch_all() {
            echo "🚀 Starting complete Microsoft environment..."
            
            # Launch Teams PWA
            echo "  Starting Teams PWA..."
            microsoft-edge --app=https://gov.teams.microsoft.us/v2 &
            
            # Launch Outlook PWA  
            echo "  Starting Outlook PWA..."
            microsoft-edge --app=https://outlook.office365.us/ &
            
            # Wait a moment for PWAs to start
            sleep 2
            
            # Launch Microsoft Edge with admin profile
            echo "  Starting Edge admin profile..."
            microsoft-edge --profile-directory="Profile 1" &
            
            echo "✅ Complete Microsoft environment started!"
            echo "   - Teams PWA"
            echo "   - Outlook PWA"
            echo "   - Edge admin profile"
        }

        # Parse arguments
        ACTION="work"  # Default action
        
        while [[ $# -gt 0 ]]; do
            case $1 in
                --work) ACTION="work"; shift ;;
                --admin) ACTION="admin"; shift ;;
                --all) ACTION="all"; shift ;;
                --help) show_help; exit 0 ;;
                *) echo "Unknown option: $1"; show_help; exit 1 ;;
            esac
        done

        case $ACTION in
            work) launch_work_profile ;;
            admin) launch_admin_profile ;;
            all) launch_all ;;
        esac
      '')
    ];
  };
}