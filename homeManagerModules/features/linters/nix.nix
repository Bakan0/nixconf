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
    # Install Nix linting and formatting tools
    home.packages = with pkgs; [
      nixfmt-rfc-style  # Official Nix formatter (becoming nixpkgs standard)
      alejandra         # Alternative formatter (fast, semantic correctness)
      deadnix           # Find unused code in Nix files
      statix            # Lints and suggestions for Nix code
    ];
  };
}
