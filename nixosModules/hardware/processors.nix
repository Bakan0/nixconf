{ config, lib, pkgs, ... }:
{
  # Hardware analysis tools - not a feature module, just provides detection scripts
  # These tools help determine optimal CPU/GPU configuration for any host

  environment.systemPackages = with pkgs; [
    # Hardware analysis script - detects CPU/GPU configuration
    (pkgs.writeShellScriptBin "hardware-analyze" ''
      #!${pkgs.bash}/bin/bash

      echo "=== Hardware Analysis Tool ==="
      echo "Detecting optimal CPU/GPU configuration for this system"
      echo ""

      # CPU Detection
      echo "--- CPU Information ---"
      CPU_VENDOR=$(${pkgs.util-linux}/bin/lscpu | grep "Vendor ID" | awk '{print $3}' | head -1)
      CPU_MODEL=$(${pkgs.util-linux}/bin/lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//' | head -1)
      echo "CPU: $CPU_MODEL"
      echo "Vendor: $CPU_VENDOR"
      echo ""

      # GPU Detection
      echo "--- GPU Information ---"
      GPUS=$(${pkgs.pciutils}/bin/lspci | grep -i vga)
      echo "$GPUS"
      echo ""

      # Count GPUs by vendor
      INTEL_GPU=$(echo "$GPUS" | grep -i intel | wc -l)
      AMD_GPU=$(echo "$GPUS" | grep -i amd | wc -l)
      NVIDIA_GPU=$(echo "$GPUS" | grep -i nvidia | wc -l)

      echo "GPU Count: Intel=$INTEL_GPU, AMD=$AMD_GPU, NVIDIA=$NVIDIA_GPU"
      echo ""

      # DRI Device Mapping
      echo "--- DRI Device Mapping ---"
      if [ -d "/dev/dri/by-path" ]; then
        echo "Available DRI devices:"
        ${pkgs.coreutils}/bin/ls -la /dev/dri/by-path/ | grep -E "(card|render)" | while read line; do
          echo "  $line"
        done
        echo ""

        # Test DRI_PRIME mappings if we have multiple GPUs
        TOTAL_GPUS=$((INTEL_GPU + AMD_GPU + NVIDIA_GPU))
        if [ $TOTAL_GPUS -gt 1 ]; then
          echo "Testing DRI_PRIME mappings:"

          for prime in 0 1; do
            GPU_INFO=$(DRI_PRIME=$prime ${pkgs.mesa-demos}/bin/glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | sed 's/^ *//' || echo "Failed")
            echo "  DRI_PRIME=$prime → $GPU_INFO"
          done
          echo ""
        fi
      fi

      echo "--- Apple Hardware Detection ---"
      if ${pkgs.pciutils}/bin/lspci | grep -qi "apple"; then
        echo "Apple hardware detected!"
        APPLE_MODEL=$(${pkgs.dmidecode}/bin/dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
        echo "Model: $APPLE_MODEL"

        # Check for T2 chip
        if ${pkgs.pciutils}/bin/lspci | grep -qi "t2"; then
          echo "T2 chip detected - MacBook with T2 security chip"
        fi
        echo ""
      else
        echo "No Apple hardware detected"
        echo ""
      fi

      echo "=== Analysis complete! ==="
      echo "Run 'hardware-config-generate' to get configuration suggestions"
    '')

    # Configuration generator - outputs copy-pasteable Nix config
    (pkgs.writeShellScriptBin "hardware-config-generate" ''
      #!${pkgs.bash}/bin/bash

      echo "=== Hardware Configuration Generator ==="
      echo "Generating optimal configuration for $(${pkgs.nettools}/bin/hostname)"
      echo ""

      # Detect hardware
      CPU_VENDOR=$(${pkgs.util-linux}/bin/lscpu | grep "Vendor ID" | awk '{print $3}' | head -1)
      GPUS=$(${pkgs.pciutils}/bin/lspci | grep -i vga)
      INTEL_GPU=$(echo "$GPUS" | grep -i intel | wc -l)
      AMD_GPU=$(echo "$GPUS" | grep -i amd | wc -l)
      NVIDIA_GPU=$(echo "$GPUS" | grep -i nvidia | wc -l)
      TOTAL_GPUS=$((INTEL_GPU + AMD_GPU + NVIDIA_GPU))

      # Apple hardware detection
      IS_APPLE=""
      if ${pkgs.pciutils}/bin/lspci | grep -qi "apple"; then
        IS_APPLE="true"
        if ${pkgs.pciutils}/bin/lspci | grep -qi "t2"; then
          IS_T2="true"
        fi
      fi

      echo "# Generated hardware configuration for $(${pkgs.nettools}/bin/hostname)"
      echo "# Add this to your hosts/$(${pkgs.nettools}/bin/hostname)/configuration.nix"
      echo ""

      # Apple-specific configuration
      if [ -n "$IS_APPLE" ]; then
        echo "    # Apple hardware support (add inside myNixOS block)"
        echo "    apple = {"
        echo "      enable = true;"
        if [ -n "$IS_T2" ]; then
          echo "      modelOverrides = \"T2\";"
        fi
        echo "    };"
        echo ""
      fi

      # Intel GPU configuration
      if [ $INTEL_GPU -gt 0 ]; then
        echo "    # Intel graphics support (add inside myNixOS block)"
        echo "    intel.enable = true;"
        echo ""
      fi

      # AMD GPU configuration
      if [ $AMD_GPU -gt 0 ]; then
        echo "    # AMD graphics support (add inside myNixOS block)"
        echo "    amd = {"
        echo "      enable = true;"

        # Determine mode based on GPU count
        if [ $TOTAL_GPUS -gt 1 ]; then
          echo "      supergfxMode = \"Hybrid\";"

          # Try to determine optimal DRI_PRIME mapping
          AMD_PRIME=""
          for prime in 0 1; do
            GPU_CHECK=$(DRI_PRIME=$prime ${pkgs.mesa-demos}/bin/glxinfo 2>/dev/null | grep -i "amd\|radeon" | head -1)
            if [ -n "$GPU_CHECK" ]; then
              AMD_PRIME=$prime
              break
            fi
          done

          if [ -n "$AMD_PRIME" ]; then
            echo "      primaryGpu = \"amd\";"
            echo "      driPrimeAmd = \"$AMD_PRIME\";"
          fi
        else
          echo "      supergfxMode = \"Integrated\";"
        fi

        echo "    };"
        echo ""
      fi

      # NVIDIA GPU configuration (placeholder for future)
      if [ $NVIDIA_GPU -gt 0 ]; then
        echo "    # NVIDIA graphics support (configure manually)"
        echo "    # nvidia.enable = true;"
        echo ""
      fi

      echo "# Copy the above configuration into your host file"
      echo "# Then run: git add -A && nh os switch ~/nixconf/. -- --show-trace"
    '')

    # Auto-insertion script with surgical git operations
    (pkgs.writeShellScriptBin "hardware-config-insert" ''
      #!${pkgs.bash}/bin/bash

      HOSTNAME=$(${pkgs.nettools}/bin/hostname)
      HOST_FILE="/home/emet/nixconf/hosts/$HOSTNAME/configuration.nix"
      COMMIT_ONLY=false
      PUSH=false

      # Parse arguments
      while [[ $# -gt 0 ]]; do
        case $1 in
          --commit-only)
            COMMIT_ONLY=true
            shift
            ;;
          --commit-and-push)
            COMMIT_ONLY=true
            PUSH=true
            shift
            ;;
          *)
            echo "Unknown option: $1"
            echo "Usage: hardware-config-insert [--commit-only] [--commit-and-push]"
            exit 1
            ;;
        esac
      done

      if [ ! -f "$HOST_FILE" ]; then
        echo "Error: Host file not found: $HOST_FILE"
        echo "Create the host first or run this on the target system"
        exit 1
      fi

      echo "=== Hardware Configuration Auto-Insert ==="
      echo "Target: $HOST_FILE"
      if [ "$COMMIT_ONLY" = true ]; then
        echo "Mode: Surgical git commit (stash → insert → commit → unstash)"
        if [ "$PUSH" = true ]; then
          echo "Push: Yes"
        else
          echo "Push: No"
        fi
      else
        echo "Mode: Insert only (no git operations)"
      fi
      echo ""

      # Check if hardware config already exists
      if grep -q "# Generated hardware configuration" "$HOST_FILE"; then
        echo "Warning: Hardware configuration already exists in $HOST_FILE"
        echo "Remove existing configuration first, or use hardware-config-generate for manual copy-paste"
        exit 1
      fi

      # Surgical git operations if requested
      if [ "$COMMIT_ONLY" = true ]; then
        echo "=== Surgical Git Operations ==="

        # Check if we're in a git repo
        if ! git rev-parse --git-dir > /dev/null 2>&1; then
          echo "Error: Not in a git repository"
          exit 1
        fi

        # Check if there are any changes to stash
        if git diff --quiet && git diff --cached --quiet; then
          echo "No changes to stash - proceeding with direct commit"
          STASH_CREATED=false
        else
          echo "Stashing current changes..."
          git stash push -m "hardware-config-insert: temporary stash $(date '+%Y-%m-%d %H:%M:%S')" || {
            echo "Error: Failed to stash changes"
            exit 1
          }
          STASH_CREATED=true
        fi
      fi

      # Generate clean configuration to temp file (no instructional comments)
      TEMP_CONFIG=$(mktemp)

      # Generate clean config without headers for auto-insert (inside myNixOS block)
      {
        # Detect hardware first
        GPUS=$(${pkgs.pciutils}/bin/lspci | grep -i vga)
        INTEL_GPU=$(echo "$GPUS" | grep -i intel | wc -l)
        AMD_GPU=$(echo "$GPUS" | grep -i amd | wc -l)
        NVIDIA_GPU=$(echo "$GPUS" | grep -i nvidia | wc -l)
        TOTAL_GPUS=$((INTEL_GPU + AMD_GPU + NVIDIA_GPU))

        # Intel GPU configuration (inside myNixOS block)
        if [ $INTEL_GPU -gt 0 ]; then
          echo ""
          echo "    # Intel graphics support"
          echo "    intel.enable = true;"
        fi

        # AMD GPU configuration (inside myNixOS block)
        if [ $AMD_GPU -gt 0 ]; then
          echo ""
          echo "    # AMD graphics support"
          echo "    amd = {"
          echo "      enable = true;"

          if [ $TOTAL_GPUS -gt 1 ]; then
            echo "      supergfxMode = \"Hybrid\";"

            # Try to determine optimal DRI_PRIME mapping
            AMD_PRIME=""
            for prime in 0 1; do
              GPU_CHECK=$(DRI_PRIME=$prime ${pkgs.mesa-demos}/bin/glxinfo 2>/dev/null | grep -i "amd\|radeon" | head -1)
              if [ -n "$GPU_CHECK" ]; then
                AMD_PRIME=$prime
                break
              fi
            done

            if [ -n "$AMD_PRIME" ]; then
              echo "      primaryGpu = \"amd\";"
              echo "      driPrimeAmd = \"$AMD_PRIME\";"
            fi
          else
            echo "      supergfxMode = \"Integrated\";"
          fi

          echo "    };"
        fi

        # NVIDIA GPU configuration (inside myNixOS block)
        if [ $NVIDIA_GPU -gt 0 ]; then
          echo ""
          echo "    # NVIDIA graphics support (configure manually)"
          echo "    # nvidia.enable = true;"
        fi
      } > "$TEMP_CONFIG"

      # Find insertion point (inside myNixOS block, before closing brace)
      if grep -q "myNixOS.*{" "$HOST_FILE"; then
        echo "Found myNixOS section, inserting hardware config inside it..."

        # Create backup
        cp "$HOST_FILE" "$HOST_FILE.backup"

        # Insert configuration before myNixOS block closes
        awk '
        /myNixOS[[:space:]]*=[[:space:]]*{/ {
          in_mynixos = 1
          brace_count = 1
          print
          next
        }
        in_mynixos {
          # Count braces to find the end of myNixOS block
          temp1 = temp2 = $0
          gsub(/[^{]/, "", temp1); brace_count += length(temp1)
          gsub(/[^}]/, "", temp2); brace_count -= length(temp2)

          # If this line closes the myNixOS block, insert hardware config before it
          if (brace_count == 0 && /^[[:space:]]*};/) {
            while ((getline line < "'"$TEMP_CONFIG"'") > 0) {
              print line
            }
            close("'"$TEMP_CONFIG"'")
            in_mynixos = 0
          }
          print
          next
        }
        { print }
        ' "$HOST_FILE" > "$HOST_FILE.tmp" && mv "$HOST_FILE.tmp" "$HOST_FILE"

        echo "Hardware configuration inserted successfully!"
        echo "Backup saved as: $HOST_FILE.backup"
        echo ""

        # Continue with git operations if requested
        if [ "$COMMIT_ONLY" = true ]; then
          echo "=== Git Commit Operations ==="

          # Stage only the host file
          git add "$HOST_FILE" || {
            echo "Error: Failed to stage $HOST_FILE"
            if [ "$STASH_CREATED" = true ]; then
              echo "Restoring stashed changes..."
              git stash pop
            fi
            exit 1
          }

          # Commit with descriptive message
          COMMIT_MSG="feat($HOSTNAME): add hardware configuration

Auto-generated hardware configuration for $HOSTNAME:
- $(grep -c "enable.*true" "$TEMP_CONFIG" 2>/dev/null || echo "Multiple") hardware features enabled
- Detected: $(lscpu | grep "Model name" | cut -d: -f2 | sed 's/^ *//')
- GPU mapping optimized for this system

🤖 Generated with hardware-config-insert"

          git commit -m "$COMMIT_MSG" || {
            echo "Error: Failed to commit changes"
            if [ "$STASH_CREATED" = true ]; then
              echo "Restoring stashed changes..."
              git stash pop
            fi
            exit 1
          }

          echo "✓ Committed hardware configuration for $HOSTNAME"

          # Push if requested
          if [ "$PUSH" = true ]; then
            echo "Pushing to remote..."
            git push || {
              echo "Warning: Failed to push to remote (commit was successful)"
            }
            echo "✓ Pushed to remote"
          fi

          # Restore stashed changes
          if [ "$STASH_CREATED" = true ]; then
            echo "Restoring stashed changes..."
            git stash pop || {
              echo "Warning: Failed to restore stashed changes"
              echo "Your changes are in: git stash list"
            }
            echo "✓ Restored stashed changes"
          fi

          echo ""
          echo "=== Complete! ==="
          echo "Hardware config committed successfully"
          if [ "$PUSH" = true ]; then
            echo "Changes have been pushed to remote"
          fi
          echo "Your working directory has been restored"
        else
          echo "Next steps:"
          echo "1. Review the changes: git diff $HOST_FILE"
          echo "2. Build and test: git add -A && nh os switch ~/nixconf/. -- --show-trace"
          echo ""
          echo "Or run with --commit-only to do surgical git operations"
        fi
      else
        echo "Error: Could not find myNixOS section in $HOST_FILE"
        echo "Use hardware-config-generate for manual copy-paste instead"
        exit 1
      fi

      rm -f "$TEMP_CONFIG"
    '')
  ];
}