{ pkgs, lib, ... }: {
  # Runtime dependencies for SonarLint extension
  home.packages = with pkgs; [
    jdk21    # LTS Java for SonarLint language server (requires Java 17+)
    nodejs   # Node.js for JavaScript/TypeScript/JSON analysis (requires 18.20.0+)
  ];

  programs.vscode = {
    enable = true;
    profiles.default = {
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
      "terminal.integrated.defaultLocation" = "bottom";
      
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

      # Prevent blank locked windows
      "window.restoreWindows" = "folders";
      "workbench.activityBar.visible" = true;
      "workbench.statusBar.visible" = true;

      # Claude Code extension settings

      # Hide the annoying Source Control panel with lock icon
      "scm.repositories.visible" = 0;
      "workbench.view.scm.visible" = false;

      # Prevent locked/blank panels and fix layout
      "workbench.auxiliaryBar.visible" = false;
      "workbench.auxiliaryBar.location" = "hidden";
      "workbench.panel.opensMaximized" = "never";
      "workbench.panel.defaultLocation" = "bottom";

      # Force layout preferences
      "workbench.editor.restoreViewState" = false;
      "workbench.editor.revealIfOpen" = true;

      # Disable problematic views that can cause locked panels
      "workbench.view.alwaysShowHeaderActions" = false;
      "workbench.editor.showTabs" = "multiple";

      # Security settings
      "security.workspace.trust.enabled" = false;
      "git.openRepositoryInParentFolders" = "never";
      };
      
      keybindings = [
        {
          key = "ctrl+;";
          command = "claude-code.runClaude";
        }
      ];
    };
  };

  # Copy declarative settings to writable location and clear bad layout state
  home.activation.vscodeSettings = lib.hm.dag.entryAfter ["linkGeneration"] ''
    settingsDir="$HOME/.config/Code/User"
    settingsFile="$settingsDir/settings.json"

    # If the file is a symlink (home-manager managed), copy it to make it writable
    if [ -L "$settingsFile" ]; then
      echo "Making VSCode settings writable while preserving declarative defaults..."
      target=$(readlink "$settingsFile")
      rm "$settingsFile"
      cp "$target" "$settingsFile"
      chmod 644 "$settingsFile"
      echo "VSCode settings are now writable. Changes will persist until next home-manager switch."
    fi

    # Clear workspace layout state that causes panel/terminal positioning issues
    workspaceStorage="$settingsDir/workspaceStorage"
    if [ -d "$workspaceStorage" ]; then
      echo "Clearing VSCode workspace layout state to fix panel positioning..."
      find "$workspaceStorage" -name "state.vscdb*" -delete 2>/dev/null || true
      echo "Workspace layout state cleared."
    fi
  '';
}