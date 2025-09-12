{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myHomeManager.claude-code-latest;
  
  # Claude Code with hash verification and auto-update capability
  # Set UPDATE_CLAUDE_HASHES=1 to auto-update hashes on build failure
  claude-code-latest = 
    let
      # Current known hashes - update these when versions change
      registryHash = "sha256-N+s3uilGIlddwQL33SGjB8f50GstTx8Ev/yYC8BEHr4=";
      sourceHash = "sha256-nXkXh+TjMkLItbqgaJbqrNm9EaRVJjYAP6RryKQm9QY=";
      depsHash = "sha256-nXkXh+TjMkLItbqgaJbqrNm9EaRVJjYAP6RryKQm9QY=";
      
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
    
    # Function to get registry hash using nix build with fake hash
    get_registry_hash() {
      local temp_expr=$(mktemp)
      
      cat > "$temp_expr" << 'EXPR'
    with import <nixpkgs> {};
    fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/";
      sha256 = lib.fakeHash;
    }
EXPR
      
      local output
      output=$(nix build --impure -f "$temp_expr" 2>&1 || true)
      rm "$temp_expr"
      
      # Extract hash from error message
      echo "$output" | grep -A1 "got:" | grep -o "sha256-[A-Za-z0-9+/=]\{44\}" | head -1 || true
    }
    
    # Function to get source hash by building claude-code with fake source hash
    get_source_hash() {
      local registry_hash="$1"
      local temp_expr=$(mktemp)
      
      cat > "$temp_expr" << 'EXPR'
with import <nixpkgs> { config.allowUnfree = true; };
let
  registryInfo = builtins.fromJSON (builtins.readFile (fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/";
    sha256 = "REGISTRY_HASH_PLACEHOLDER";
  }));
  latestVersion = registryInfo.dist-tags.latest;
in
claude-code.overrideAttrs (oldAttrs: rec {
  version = latestVersion;
  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$${latestVersion}.tgz";
    hash = lib.fakeHash;
  };
  npmDepsHash = "sha256-nXkXh+TjMkLItbqgaJbqrNm9EaRVJjYAP6RryKQm9QY=";
})
EXPR
      
      ${pkgs.gnused}/bin/sed -i "s|REGISTRY_HASH_PLACEHOLDER|$registry_hash|g" "$temp_expr"
      
      local output
      output=$(nix build --impure -f "$temp_expr" 2>&1 || true)
      rm "$temp_expr"
      
      # Extract source hash from error message
      echo "$output" | grep -A1 "got:" | grep -o "sha256-[A-Za-z0-9+/=]\{44\}" | head -1 || true
    }
    
    # Function to get deps hash by building claude-code with fake deps hash
    get_deps_hash() {
      local registry_hash="$1"
      local source_hash="$2"
      local temp_expr=$(mktemp)
      
      cat > "$temp_expr" << 'EXPR'
with import <nixpkgs> { config.allowUnfree = true; };
let
  registryInfo = builtins.fromJSON (builtins.readFile (fetchurl {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/";
    sha256 = "REGISTRY_HASH_PLACEHOLDER";
  }));
  latestVersion = registryInfo.dist-tags.latest;
in
claude-code.overrideAttrs (oldAttrs: rec {
  version = latestVersion;
  src = fetchzip {
    url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$${latestVersion}.tgz";
    hash = "SOURCE_HASH_PLACEHOLDER";
  };
  npmDepsHash = lib.fakeHash;
})
EXPR
      
      ${pkgs.gnused}/bin/sed -i "s|REGISTRY_HASH_PLACEHOLDER|$registry_hash|g" "$temp_expr"
      ${pkgs.gnused}/bin/sed -i "s|SOURCE_HASH_PLACEHOLDER|$source_hash|g" "$temp_expr"
      
      local output
      output=$(nix build --impure -f "$temp_expr" 2>&1 || true)
      rm "$temp_expr"
      
      # If build succeeded, deps hash = source hash, otherwise extract from error
      if echo "$output" | grep -q "error:"; then
        echo "$output" | grep -A1 "got:" | grep -o "sha256-[A-Za-z0-9+/=]\{44\}" | tail -1 || echo "$source_hash"
      else
        echo "$source_hash"
      fi
    }
    
    echo "Getting registry hash..."
    NEW_REGISTRY_HASH=$(get_registry_hash)
    
    if [[ -z "$NEW_REGISTRY_HASH" ]]; then
      echo "❌ Could not determine registry hash"
      exit 1
    fi
    
    echo "Registry hash: $NEW_REGISTRY_HASH"
    
    echo "Getting source hash..."
    NEW_SOURCE_HASH=$(get_source_hash "$NEW_REGISTRY_HASH")
    
    if [[ -z "$NEW_SOURCE_HASH" ]]; then
      echo "❌ Could not determine source hash"
      exit 1
    fi
    
    echo "Source hash: $NEW_SOURCE_HASH"
    
    echo "Getting deps hash..."
    NEW_DEPS_HASH=$(get_deps_hash "$NEW_REGISTRY_HASH" "$NEW_SOURCE_HASH")
    
    if [[ -z "$NEW_DEPS_HASH" ]]; then
      echo "❌ Could not determine dependencies hash"
      exit 1
    fi
    
    echo "Deps hash: $NEW_DEPS_HASH"
    
    # Update all hashes in the module file
    ${pkgs.gnused}/bin/sed -i "s|registryHash = \"sha256-[^\"]*\"|registryHash = \"$NEW_REGISTRY_HASH\"|g" "$MODULE_FILE"
    ${pkgs.gnused}/bin/sed -i "s|sourceHash = \"sha256-[^\"]*\"|sourceHash = \"$NEW_SOURCE_HASH\"|g" "$MODULE_FILE"
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
