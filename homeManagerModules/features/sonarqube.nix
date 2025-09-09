{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let cfg = config.myHomeManager.sonarqube;
in {
  config = mkIf cfg.enable {
    # Compilation database generation tools for SonarQube C/C++ analysis
    home.packages = with pkgs; [
      bear                 # Generate compile_commands.json for Make-based projects
      cmake                # CMake build system (supports CMAKE_EXPORT_COMPILE_COMMANDS)
      ninja                # Build system used by many CMake generators
    ];

    # VS Code extensions for compilation database generation
    programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
      ms-vscode.makefile-tools    # Auto-generates compile_commands.json
    ];

    # VS Code settings for SonarQube C/C++ support
    programs.vscode.profiles.default.userSettings = {
      # Makefile Tools extension configuration
      "makefile.extensionOutputFolder" = "./.vscode";
      "makefile.extensionLog" = "Verbose";
      "makefile.saveBeforeBuildOrConfigure" = true;
      
      # C/C++ configuration for better integration
      "C_Cpp.default.compilerPath" = "${pkgs.clang}/bin/clang";
      "C_Cpp.default.cStandard" = "c17";
      "C_Cpp.default.cppStandard" = "c++20";
      
      # Default compilation database path (CMake standard location)
      "sonarlint.pathToCompileCommands" = "./build/compile_commands.json";
    };
  };
}
