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
    # Install PowerShell and PSScriptAnalyzer
    home.packages = with pkgs; [
      powershell
    ];

    # Global PSScriptAnalyzer configuration using Microsoft's official settings
    home.file."PSScriptAnalyzerSettings.psd1".text = ''
      @{
          # Severity levels - focus on errors and warnings
          Severity = @('Error', 'Warning')
          
          # Exclude rules that might be too strict for scripts
          ExcludeRules = @(
              'PSAvoidUsingCmdletAliases',    # Allow common aliases like ls, cd
              'PSAvoidUsingWriteHost'         # Allow Write-Host for interactive scripts
          )
          
          # Include essential rules for Azure/PowerShell development
          IncludeRules = @(
              'PSAvoidUsingPlainTextForPassword',
              'PSAvoidUsingConvertToSecureStringWithPlainText',
              'PSUseSingularNouns',
              'PSUseApprovedVerbs',
              'PSUseDeclaredVarsMoreThanAssignments'
          )
          
          # Enable compatibility checking without restrictive version targeting
          Rules = @{
              PSUseCompatibleSyntax = @{
                  Enable = $true
              }
              PSUseCompatibleCommands = @{
                  Enable = $true
              }
          }
      }
    '';

    # PowerShell profile configuration to automatically use PSScriptAnalyzer settings
    home.file.".config/powershell/Microsoft.PowerShell_profile.ps1".text = ''
      # Auto-load PSScriptAnalyzer settings from home directory
      $PSScriptAnalyzerSettingsPath = "$HOME/PSScriptAnalyzerSettings.psd1"
      
      # Function to quickly analyze current script
      function Invoke-ScriptAnalysis {
          param([string]$Path = $pwd)
          if (Test-Path $PSScriptAnalyzerSettingsPath) {
              Invoke-ScriptAnalyzer -Path $Path -Settings $PSScriptAnalyzerSettingsPath
          } else {
              Invoke-ScriptAnalyzer -Path $Path
          }
      }
      
      # Alias for quick analysis
      Set-Alias -Name 'analyze' -Value 'Invoke-ScriptAnalysis'
    '';
  };
}
