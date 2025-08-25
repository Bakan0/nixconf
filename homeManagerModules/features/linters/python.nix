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
    # Install ruff - the modern Python linter and formatter
    home.packages = with pkgs; [
      ruff
    ];

    # Global ruff configuration using official Astral-sh recommendations
    home.file."pyproject.toml".text = ''
      [tool.ruff]
      # Same as Black formatter
      line-length = 88
      indent-width = 4
      # Target Python 3.12+ for modern features
      target-version = "py312"
      
      # Exclude common directories
      exclude = [
          ".bzr",
          ".direnv", 
          ".eggs",
          ".git",
          ".git-rewrite",
          ".hg",
          ".mypy_cache",
          ".nox",
          ".pants.d",
          ".pyenv",
          ".pytest_cache",
          ".pytype",
          ".ruff_cache",
          ".svn",
          ".tox",
          ".venv",
          ".vscode",
          "__pypackages__",
          "_build",
          "buck-out",
          "build",
          "dist",
          "node_modules",
          "site-packages",
          "venv",
      ]

      [tool.ruff.lint]
      # Start with essential rules, expand gradually
      select = [
          "E",   # pycodestyle errors  
          "F",   # Pyflakes
          "B",   # flake8-bugbear (popular extension)
          "I",   # isort imports
          "UP",  # pyupgrade (modernize Python code)
          "N",   # pep8-naming
          "W",   # pycodestyle warnings
      ]
      
      # Auto-fix safe rules
      fixable = [
          "F401",   # Remove unused imports
          "I001",   # Sort imports
          "UP",     # Upgrade syntax
          "RUF100", # Remove unused noqa comments
      ]
      
      # Per-file customizations
      [tool.ruff.lint.per-file-ignores]
      "__init__.py" = ["E402", "F401", "F403", "F811"]  # Allow common __init__.py patterns

      [tool.ruff.format]
      # Use double quotes for strings (Black compatible)
      quote-style = "double"
      # Indent with spaces, not tabs
      indent-style = "space"
      # Respect magic trailing commas
      skip-magic-trailing-comma = false
      # Auto-format docstrings
      docstring-code-format = true
      docstring-code-line-length = 72
    '';
  };
}
