{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myHomeManager.claude-code-latest;
  
  # Claude Code with hash verification and auto-update capability
  # Set UPDATE_CLAUDE_HASHES=1 to auto-update hashes on build failure
  claude-code-latest =
    let
      # Current known hashes - update these when versions change (SRI format)
      registryHash = "sha256-OLfSFUAOKLM26AUmiMcentHh2znhHDhVtKxo6QFCmLU=";
      sourceHash = "sha256-ix/JSPBLnvCPtyqJ6beAaOpuimphpkrkIw5HCdeeGkM=";
      depsHash = "sha256-ix/JSPBLnvCPtyqJ6beAaOpuimphpkrkIw5HCdeeGkM=";

      # Fetch registry info with hash verification
      registryInfo = builtins.fromJSON (builtins.readFile (pkgs.fetchurl {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/";
        hash = registryHash;
      }));
      latestVersion = registryInfo.dist-tags.latest;

    in
    # Use stdenv directly since tarball contains pre-built cli.js
    pkgs.stdenv.mkDerivation {
      pname = "claude-code";
      version = latestVersion;

      src = pkgs.fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${latestVersion}.tgz";
        hash = sourceHash;
      };

      nativeBuildInputs = [ pkgs.makeWrapper ];

      installPhase = ''
        runHook preInstall

        mkdir -p $out/lib/claude-code $out/bin
        cp -r . $out/lib/claude-code

        makeWrapper ${pkgs.nodejs}/bin/node $out/bin/claude \
          --add-flags "$out/lib/claude-code/cli.js" \
          --set DISABLE_AUTOUPDATER 1 \
          --set AUTHORIZED 1 \
          --unset DEV

        runHook postInstall
      '';

      meta = {
        description = "Agentic coding tool that lives in your terminal";
        homepage = "https://github.com/anthropics/claude-code";
        license = lib.licenses.unfree;
        mainProgram = "claude";
      };
    };

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

    # Get registry hash using nix-prefetch-url and convert to SRI format
    echo "Getting registry hash..."
    REGISTRY_HASH_NIX32=$(${pkgs.nix}/bin/nix-prefetch-url https://registry.npmjs.org/@anthropic-ai/claude-code/ 2>/dev/null)
    REGISTRY_HASH=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$REGISTRY_HASH_NIX32")

    if [[ -z "$REGISTRY_HASH" ]]; then
      echo "❌ Failed to get registry hash"
      exit 1
    fi

    # Get source hash using nix-prefetch-url and convert to SRI format
    echo "Getting source hash..."
    SOURCE_HASH_NIX32=$(${pkgs.nix}/bin/nix-prefetch-url --unpack "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$LATEST_VERSION.tgz" 2>/dev/null)
    SOURCE_HASH=$(${pkgs.nix}/bin/nix hash to-sri --type sha256 "$SOURCE_HASH_NIX32")

    if [[ -z "$SOURCE_HASH" ]]; then
      echo "❌ Failed to get source hash"
      exit 1
    fi

    echo ""
    echo "=== RESULTS ==="
    echo "Version: $LATEST_VERSION"
    echo ""
    echo "⚠️  IMPORTANT: Hashes in SRI format (sha256-...) to match base package format"
    echo ""
    echo "Update the following lines in homeManagerModules/features/claude-code-latest.nix:"
    echo ""
    echo "registryHash = \"$REGISTRY_HASH\";"
    echo "sourceHash = \"$SOURCE_HASH\";"
    echo "depsHash = \"$SOURCE_HASH\";  # May need adjustment after first build"
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
