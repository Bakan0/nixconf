{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myHomeManager.claude-code-latest;
  
  # Claude Code with hash verification and auto-update capability
  # Set UPDATE_CLAUDE_HASHES=1 to auto-update hashes on build failure
  claude-code-latest = 
    let
      # Current known hashes - update these when versions change
      registryHash = "sha256-BjivV3r3dJZekToSEtOZEkF+FwRc95G1wVP2n7MeN6c=";
      sourceHash = "sha256-V4ubz9wCwxayR4mh7Mkkqp/aje23NM1rnfECZhnYSXw=";
      depsHash = "sha256-V4ubz9wCwxayR4mh7Mkkqp/aje23NM1rnfECZhnYSXw=";
      
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

  # Hash updater script
  claude-hash-update = pkgs.writeShellScriptBin "claude-hash-update" ''
    set -euo pipefail
    
    MODULE_FILE="$HOME/nixconf/homeManagerModules/features/claude-code-latest.nix"
    SYSTEM="${pkgs.system}"
    
    if [[ ! -f "$MODULE_FILE" ]]; then
      echo "Error: Claude module not found at $MODULE_FILE"
      exit 1
    fi
    
    echo "Updating Claude Code hashes..."
    
    # Function to get actual hash by attempting fetch with fake hash
    get_actual_hash() {
      local url="$1"
      local temp_expr=$(mktemp)
      
      # Create temporary expression to fetch with fake hash
      cat > "$temp_expr" << 'EXPR'
    with import <nixpkgs> {};
    fetchurl {
      url = "URL_PLACEHOLDER";
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    }
EXPR
      
      # Replace placeholder
      ${pkgs.gnused}/bin/sed -i "s|URL_PLACEHOLDER|$url|g" "$temp_expr"
      
      # Attempt build and extract actual hash from error
      local output
      output=$(nix-build "$temp_expr" --no-out-link 2>&1 || true)
      rm "$temp_expr"
      
      # Extract the "got:" hash from error message
      echo "$output" | grep -A1 "got:" | grep -o "sha256-[A-Za-z0-9+/=]\{44\}" | head -1 || true
    }
    
    # Function to get npm deps hash by building with fake deps hash
    get_deps_hash() {
      local version="$1"
      local source_hash="$2"
      local temp_expr=$(mktemp)
      
      # Create temporary expression for claude-code with known source but fake deps hash
      cat > "$temp_expr" << 'EXPR'
    with import <nixpkgs> { config.allowUnfree = true; };
    claude-code.overrideAttrs (oldAttrs: rec {
      version = "VERSION_PLACEHOLDER";
      src = fetchzip {
        url = "URL_PLACEHOLDER";
        hash = "HASH_PLACEHOLDER";
      };
      npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    })
EXPR
      
      # Replace placeholders
      ${pkgs.gnused}/bin/sed -i "s|VERSION_PLACEHOLDER|$version|g" "$temp_expr"
      ${pkgs.gnused}/bin/sed -i "s|URL_PLACEHOLDER|https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$version.tgz|g" "$temp_expr"
      ${pkgs.gnused}/bin/sed -i "s|HASH_PLACEHOLDER|$source_hash|g" "$temp_expr"
      
      # Attempt build and extract actual deps hash
      local output
      output=$(nix-build "$temp_expr" --no-out-link 2>&1 || true)
      rm "$temp_expr"
      
      # Extract the "got:" hash from error message  
      echo "$output" | grep -A1 "got:" | grep -o "sha256-[A-Za-z0-9+/=]\{44\}" | head -1 || true
    }
    
    echo "Fetching latest version..."
    
    # Get latest version from registry
    REGISTRY_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/"
    
    # First, get the correct registry hash
    echo "Getting registry hash..."
    NEW_REGISTRY_HASH=$(get_actual_hash "$REGISTRY_URL")
    
    if [[ -z "$NEW_REGISTRY_HASH" ]]; then
      echo "❌ Could not determine registry hash"
      exit 1
    fi
    
    echo "Registry hash: $NEW_REGISTRY_HASH"
    
    # Update registry hash and get version info
    ${pkgs.gnused}/bin/sed -i "s|registryHash = \"sha256-[^\"]*\"|registryHash = \"$NEW_REGISTRY_HASH\"|g" "$MODULE_FILE"
    
    # Get latest version by building registry fetch
    echo "Getting version..."
    TEMP_VERSION_EXPR=$(mktemp)
    cat > "$TEMP_VERSION_EXPR" << 'EXPR'
    with import <nixpkgs> {};
    let
      registryInfo = builtins.fromJSON (builtins.readFile (fetchurl {
        url = "REGISTRY_URL_PLACEHOLDER";
        sha256 = "REGISTRY_HASH_PLACEHOLDER";
      }));
    in
    writeText "version" registryInfo.dist-tags.latest
EXPR
    
    # Replace placeholders
    ${pkgs.gnused}/bin/sed -i "s|REGISTRY_URL_PLACEHOLDER|$REGISTRY_URL|g" "$TEMP_VERSION_EXPR"
    ${pkgs.gnused}/bin/sed -i "s|REGISTRY_HASH_PLACEHOLDER|$NEW_REGISTRY_HASH|g" "$TEMP_VERSION_EXPR"
    
    LATEST_VERSION=$(nix-build "$TEMP_VERSION_EXPR" --no-out-link | xargs cat)
    rm "$TEMP_VERSION_EXPR"
    
    echo "Latest version: $LATEST_VERSION"
    
    # Get source hash
    echo "Getting source hash..."
    SOURCE_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$LATEST_VERSION.tgz"
    NEW_SOURCE_HASH=$(get_actual_hash "$SOURCE_URL")
    
    if [[ -z "$NEW_SOURCE_HASH" ]]; then
      echo "❌ Could not determine source hash"
      exit 1
    fi
    
    echo "Source hash: $NEW_SOURCE_HASH"
    ${pkgs.gnused}/bin/sed -i "s|sourceHash = \"sha256-[^\"]*\"|sourceHash = \"$NEW_SOURCE_HASH\"|g" "$MODULE_FILE"
    
    # Get deps hash
    echo "Getting deps hash..."
    NEW_DEPS_HASH=$(get_deps_hash "$LATEST_VERSION" "$NEW_SOURCE_HASH")
    
    if [[ -z "$NEW_DEPS_HASH" ]]; then
      echo "❌ Could not determine dependencies hash"
      exit 1
    fi
    
    echo "Deps hash: $NEW_DEPS_HASH"
    ${pkgs.gnused}/bin/sed -i "s|depsHash = \"sha256-[^\"]*\"|depsHash = \"$NEW_DEPS_HASH\"|g" "$MODULE_FILE"
    
    echo "Hashes updated."
    echo "Registry: $NEW_REGISTRY_HASH"
    echo "Source: $NEW_SOURCE_HASH" 
    echo "Dependencies: $NEW_DEPS_HASH"
  '';
  
in {
  config = mkIf cfg.enable {
    home.packages = [ 
      claude-code-latest
      claude-hash-update  # Run this when hashes need updating
    ];
  };
}
