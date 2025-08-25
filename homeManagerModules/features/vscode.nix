{ pkgs, lib, ... }: {
  # Runtime dependencies for SonarLint extension
  home.packages = with pkgs; [
    jdk21    # LTS Java for SonarLint language server (requires Java 17+)
    nodejs   # Node.js for JavaScript/TypeScript/JSON analysis (requires 18.20.0+)
  ];

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      # Vim editing
      vscodevim.vim
      
      # Nix support  
      bbenoist.nix
      
      # Code quality and linting
      sonarsource.sonarlint-vscode
      
      # YAML support with yamllint
      redhat.vscode-yaml
      
      # Note: Using official Anthropic Claude Code extension (installed manually)
    ];
    
    userSettings = {
      # Editor settings
      "editor.fontFamily" = lib.mkDefault "'JetBrainsMono Nerd Font Mono', 'Fira Code', monospace";
      "editor.fontSize" = lib.mkDefault 14;
      "editor.fontLigatures" = lib.mkDefault true;
      "editor.formatOnSave" = lib.mkDefault true;
      
      # Theme and appearance
      "workbench.colorTheme" = lib.mkDefault "Catppuccin Macchiato";
      "workbench.iconTheme" = lib.mkDefault "catppuccin-macchiato";
      
      # Terminal settings (Linux + Kitty)
      "terminal.integrated.fontFamily" = lib.mkDefault "'JetBrainsMono Nerd Font Mono'";
      "terminal.external.linuxExec" = lib.mkDefault "kitty";
      "terminal.integrated.defaultProfile.linux" = lib.mkDefault "fish";
      
      # Vim extension settings
      "vim.leader" = lib.mkDefault "<space>";
      "vim.useSystemClipboard" = lib.mkDefault true;
      "vim.hlsearch" = lib.mkDefault true;
      "vim.insertModeKeyBindings" = [
        {
          "before" = ["j" "k"];
          "after" = ["<Esc>"];
        }
      ];
      "vim.normalModeKeyBindingsNonRecursive" = [
        {
          "before" = ["<leader>" "w"];
          "commands" = ["workbench.action.files.save"];
        }
        {
          "before" = ["<C-h>"];
          "commands" = ["workbench.action.navigateLeft"];
        }
        {
          "before" = ["<C-l>"];
          "commands" = ["workbench.action.navigateRight"];
        }
        {
          "before" = ["<C-k>"];
          "commands" = ["workbench.action.navigateUp"];
        }
        {
          "before" = ["<C-j>"];
          "commands" = ["workbench.action.navigateDown"];
        }
      ];
      
      # Git settings
      "git.enableSmartCommit" = lib.mkDefault true;
      "git.confirmSync" = lib.mkDefault false;
      
      # Nix language support
      "nix.enableLanguageServer" = lib.mkDefault true;
      "nix.serverPath" = lib.mkDefault "nil";
      
      # SonarLint runtime configuration
      "sonarlint.ls.javaHome" = lib.mkDefault "${pkgs.jdk21}/lib/openjdk";
      "sonarlint.pathToNodeExecutable" = lib.mkDefault "${pkgs.nodejs}/bin/node";
      
      # Privacy and telemetry settings - DISABLE ALL THE THINGS!
      "telemetry.telemetryLevel" = "off";
      "workbench.enableExperiments" = false;
      "workbench.settings.enableNaturalLanguageSearch" = false;
      "extensions.autoUpdate" = true;  # Keep extensions updated
      "extensions.ignoreRecommendations" = true;
      "update.mode" = "none";
      "update.showReleaseNotes" = false;
      "redhat.telemetry.enabled" = false;
      
      # Disable Microsoft's data collection
      "dotnetAcquisitionExtension.enableTelemetry" = false;
      "java.configuration.checkProjectSettingsExclusions" = false;
      "java.help.collectErrorLog" = false;
      "python.defaultInterpreterPath" = "/usr/bin/python3";
      
      # Disable annoying features
      "editor.acceptSuggestionOnEnter" = "off";
      "editor.suggestOnTriggerCharacters" = false;
      "workbench.tips.enabled" = false;
      "workbench.startupEditor" = "none";
      "extensions.showRecommendationsOnlyOnDemand" = true;
      
      # Security settings
      "security.workspace.trust.enabled" = false;
      "git.openRepositoryInParentFolders" = "never";
    };
  };
}