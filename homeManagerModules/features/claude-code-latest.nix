{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myHomeManager.claude-code-latest;
  
  # Claude Code with hash verification and auto-update capability
  # Set UPDATE_CLAUDE_HASHES=1 to auto-update hashes on build failure
  claude-code-latest = 
    let
      # Current known hashes - update these when versions change
      registryHash = "sha256:08jjjr6n20gxz31a5zbwy1ppzqxjkfm9227fnnglnrhdwj6k8jka";
      sourceHash = "sha256:110lrfhmvl9rj3ik4ksibiq9ahrs5s10kskf18ahdhvawwpc1b61";
      depsHash = "sha256:110lrfhmvl9rj3ik4ksibiq9ahrs5s10kskf18ahdhvawwpc1b61";
      
      # Fetch registry info with hash verification
      registryInfo = builtins.fromJSON (builtins.readFile (pkgs.fetchurl {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/";
        sha256 = registryHash;
      }));
      latestVersion = registryInfo.dist-tags.latest;
      
    in
    pkgs.claude-code.overrideAttrs (oldAttrs: rec {
      version = latestVersion;
      src = pkgs.fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${latestVersion}.tgz";
        hash = sourceHash;
      };
      npmDepsHash = depsHash;
      
      # Add some debug info
      preBuild = ''
        echo "Building Claude Code version: ${latestVersion}"
        echo "Source hash: ${sourceHash}"
        echo "NPM deps hash: ${depsHash}"
      '';
    });

  # Simple hash fetcher script - outputs hashes for Claude to apply manually
  claude-hash-fetch = pkgs.writeShellScriptBin "claude-hash-fetch" ''
    set -euo pipefail
    
    echo "=== Claude Code Hash Fetcher ==="
    echo "This script fetches current hashes for Claude Code npm package."
    echo "Copy the output hashes and paste them into the module file."
    echo ""
    
    # Get latest version from npm registry
    echo "Fetching latest version info..."
    LATEST_VERSION=$(${pkgs.curl}/bin/curl -s https://registry.npmjs.org/@anthropic-ai/claude-code/ | ${pkgs.jq}/bin/jq -r '.["dist-tags"].latest')
    
    if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
      echo "❌ Failed to fetch latest version"
      exit 1
    fi
    
    echo "Latest version: $LATEST_VERSION"
    echo ""
    
    # Get registry hash using nix-prefetch-url
    echo "Getting registry hash..."
    REGISTRY_HASH=$(${pkgs.nix}/bin/nix-prefetch-url https://registry.npmjs.org/@anthropic-ai/claude-code/ 2>/dev/null | ${pkgs.coreutils}/bin/tail -1)
    
    if [[ -z "$REGISTRY_HASH" ]]; then
      echo "❌ Failed to get registry hash"
      exit 1
    fi
    
    # Get source hash using nix-prefetch-url  
    echo "Getting source hash..."
    SOURCE_HASH=$(${pkgs.nix}/bin/nix-prefetch-url --unpack "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$LATEST_VERSION.tgz" 2>/dev/null | ${pkgs.coreutils}/bin/tail -1)
    
    if [[ -z "$SOURCE_HASH" ]]; then
      echo "❌ Failed to get source hash"
      exit 1
    fi
    
    echo ""
    echo "=== RESULTS ==="
    echo "Version: $LATEST_VERSION"
    echo ""
    echo "Update the following lines in homeManagerModules/features/claude-code-latest.nix:"
    echo ""
    echo "registryHash = \"sha256:$REGISTRY_HASH\";"
    echo "sourceHash = \"sha256:$SOURCE_HASH\";"
    echo "depsHash = \"sha256:$SOURCE_HASH\";  # Usually same as source"
    echo ""
    echo "=== END RESULTS ==="
  '';
  
in {
  config = mkIf cfg.enable {
    home.packages = [ 
      claude-code-latest
      claude-hash-fetch  # Run this to get hashes for Claude to apply
    ];
  };
}
