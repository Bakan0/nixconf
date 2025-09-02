{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myHomeManager.claude-code-latest;
  
  # Claude Code with hash verification and auto-update capability
  # Set UPDATE_CLAUDE_HASHES=1 to auto-update hashes on build failure
  claude-code-latest = 
    let
      # Current known hashes - update these when versions change
      registryHash = "sha256-sBbrPPzAMT50TBgi7fIkrmLOyQ6ZMhtVAJhNh64rC/g=";
      sourceHash = "sha256-NtxWKpWsKZI2MeR3WPxB7KtDV+QK6/PLf1cV6ImQrrw=";
      depsHash = "sha256-Wm6h2S/T9nqztyJrZovYKgqJyBj4xNQsRLC0wYFoDlk=";
      
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

  # Auto-hash updater script
  update-claude-hashes = pkgs.writeShellScriptBin "update-claude-hashes" ''
    set -euo pipefail
    
    MODULE_FILE="$HOME/nixconf/homeManagerModules/features/claude-code-latest.nix"
    
    if [[ ! -f "$MODULE_FILE" ]]; then
      echo "Error: Claude module not found at $MODULE_FILE"
      exit 1
    fi
    
    echo "🔄 Auto-updating Claude Code hashes..."
    
    # Function to get actual hash by attempting fetch with fake hash
    get_actual_hash() {
      local url="$1"
      local temp_expr=$(mktemp)
      
      # Create temporary expression to fetch with fake hash
      cat > "$temp_expr" << EXPR
    with import <nixpkgs> {};
    fetchurl {
      url = "$url";
      sha256 = "0000000000000000000000000000000000000000000000000000";
    }
EXPR
      
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
      cat > "$temp_expr" << EXPR
    with import <nixpkgs> {};
    claude-code.overrideAttrs (oldAttrs: rec {
      version = "$version";
      src = fetchzip {
        url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$version.tgz";
        hash = "$source_hash";
      };
      npmDepsHash = "sha256-0000000000000000000000000000000000000000000=";
    })
EXPR
      
      # Attempt build and extract actual deps hash
      local output
      output=$(nix-build "$temp_expr" --no-out-link 2>&1 || true)
      rm "$temp_expr"
      
      # Extract the "got:" hash from error message
      echo "$output" | grep -A1 "got:" | grep -o "sha256-[A-Za-z0-9+/=]\{44\}" | head -1 || true
    }
    
    echo "📡 Fetching latest version info..."
    
    # Get latest version from registry
    REGISTRY_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/"
    
    # First, get the correct registry hash
    echo "🔍 Determining registry hash..."
    NEW_REGISTRY_HASH=$(get_actual_hash "$REGISTRY_URL")
    
    if [[ -z "$NEW_REGISTRY_HASH" ]]; then
      echo "❌ Could not determine registry hash"
      exit 1
    fi
    
    echo "📡 Registry hash: $NEW_REGISTRY_HASH"
    
    # Update registry hash and get version info
    ${pkgs.gnused}/bin/sed -i "s|registryHash = \"sha256-[^\"]*\"|registryHash = \"$NEW_REGISTRY_HASH\"|g" "$MODULE_FILE"
    
    # Get latest version by building registry fetch
    echo "🔍 Getting latest version..."
    TEMP_VERSION_EXPR=$(mktemp)
    cat > "$TEMP_VERSION_EXPR" << EXPR
    with import <nixpkgs> {};
    let
      registryInfo = builtins.fromJSON (builtins.readFile (fetchurl {
        url = "$REGISTRY_URL";
        sha256 = "$NEW_REGISTRY_HASH";
      }));
    in
    writeText "version" registryInfo.dist-tags.latest
EXPR
    
    LATEST_VERSION=$(nix-build "$TEMP_VERSION_EXPR" --no-out-link | xargs cat)
    rm "$TEMP_VERSION_EXPR"
    
    echo "📦 Latest version: $LATEST_VERSION"
    
    # Get source hash
    echo "🔍 Determining source hash..."
    SOURCE_URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$LATEST_VERSION.tgz"
    NEW_SOURCE_HASH=$(get_actual_hash "$SOURCE_URL")
    
    if [[ -z "$NEW_SOURCE_HASH" ]]; then
      echo "❌ Could not determine source hash"
      exit 1
    fi
    
    echo "📦 Source hash: $NEW_SOURCE_HASH"
    ${pkgs.gnused}/bin/sed -i "s|sourceHash = \"sha256-[^\"]*\"|sourceHash = \"$NEW_SOURCE_HASH\"|g" "$MODULE_FILE"
    
    # Get deps hash
    echo "🔍 Determining NPM dependencies hash..."
    NEW_DEPS_HASH=$(get_deps_hash "$LATEST_VERSION" "$NEW_SOURCE_HASH")
    
    if [[ -z "$NEW_DEPS_HASH" ]]; then
      echo "❌ Could not determine dependencies hash"
      exit 1
    fi
    
    echo "📚 Dependencies hash: $NEW_DEPS_HASH"
    ${pkgs.gnused}/bin/sed -i "s|depsHash = \"sha256-[^\"]*\"|depsHash = \"$NEW_DEPS_HASH\"|g" "$MODULE_FILE"
    
    echo "✅ All hashes updated successfully!"
    echo "   Registry: $NEW_REGISTRY_HASH"
    echo "   Source: $NEW_SOURCE_HASH" 
    echo "   Dependencies: $NEW_DEPS_HASH"
    echo ""
    echo "🚀 Run 'nh os switch ~/nixconf/. -- --show-trace' to build with new hashes."
  '';
  
in {
  config = mkIf cfg.enable {
    home.packages = [ 
      claude-code-latest
      update-claude-hashes  # Run this when hashes need updating
    ];
  };
}
