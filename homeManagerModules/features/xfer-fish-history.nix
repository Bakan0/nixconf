{ config, lib, pkgs, ... }:
with pkgs;
{
  home.packages = [
    (writeShellScriptBin "xfer-fish-history" ''
      set -euo pipefail

      FISH_HISTORY_PATH="$HOME/.local/share/fish/fish_history"

      show_help() {
          echo "Usage: xfer-fish-history [--send|--receive|--merge] <target_ip> [--dry-run]"
          echo "Transfer Fish shell history between hosts using zstd+rsync"
          echo ""
          echo "Operations:"
          echo "  --send     Replace remote history with local history"
          echo "  --receive  Replace local history with remote history"
          echo "  --merge    Intelligently merge local and remote histories by timestamp"
          echo ""
          echo "Examples:"
          echo "  xfer-fish-history --send 10.17.19.89"
          echo "  xfer-fish-history --receive 10.17.19.89 --dry-run"
          echo "  xfer-fish-history --merge 10.17.19.89"
      }

      # Function to merge fish history files
      merge_fish_histories() {
          local local_file="$1"
          local remote_file="$2"
          local output_file="$3"

          echo "Merging fish histories..."

          # Create temporary work directory
          local temp_dir=$(mktemp -d)
          local combined="$temp_dir/combined"
          local sorted="$temp_dir/sorted"

          # Combine both files
          touch "$combined"
          [ -f "$local_file" ] && cat "$local_file" >> "$combined"
          [ -f "$remote_file" ] && cat "$remote_file" >> "$combined"

          # Parse, deduplicate, and sort by timestamp using awk
          ${pkgs.gawk}/bin/awk '
              BEGIN { entry = ""; timestamp = 0 }
              /^- cmd:/ {
                  if (entry != "") {
                      # Store previous entry
                      key = cmd "|" timestamp
                      if (!(key in seen) || timestamp > seen_time[key]) {
                          entries[key] = entry
                          seen[key] = 1
                          seen_time[key] = timestamp
                      }
                  }
                  entry = $0 "\n"
                  cmd = substr($0, 7)  # Remove "- cmd: "
                  timestamp = 0
              }
              /^  when:/ {
                  timestamp = $2
                  entry = entry $0 "\n"
              }
              /^  paths:/ || /^  pwd:/ {
                  entry = entry $0 "\n"
              }
              END {
                  # Handle last entry
                  if (entry != "") {
                      key = cmd "|" timestamp
                      if (!(key in seen) || timestamp > seen_time[key]) {
                          entries[key] = entry
                          seen[key] = 1
                          seen_time[key] = timestamp
                      }
                  }

                  # Sort by timestamp and output
                  n = asorti(seen_time, sorted_keys)
                  for (i = 1; i <= n; i++) {
                      key = sorted_keys[i]
                      printf "%s", entries[key]
                  }
              }
          ' "$combined" > "$sorted"

          # Write to output file
          cp "$sorted" "$output_file"

          # Show merge stats
          local local_count=$(grep -c "^- cmd:" "$local_file" 2>/dev/null || echo 0)
          local remote_count=$(grep -c "^- cmd:" "$remote_file" 2>/dev/null || echo 0)
          local merged_count=$(grep -c "^- cmd:" "$output_file" 2>/dev/null || echo 0)

          echo "Merge complete:"
          echo "  Local entries:  $local_count"
          echo "  Remote entries: $remote_count"
          echo "  Merged total:   $merged_count (duplicates removed)"

          rm -rf "$temp_dir"
      }

      # Parse arguments
      ACTION=""
      TARGET_IP=""
      DRY_RUN=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              --send) ACTION="send"; TARGET_IP="$2"; shift 2 ;;
              --receive) ACTION="receive"; TARGET_IP="$2"; shift 2 ;;
              --merge) ACTION="merge"; TARGET_IP="$2"; shift 2 ;;
              --dry-run) DRY_RUN="--dry-run"; shift ;;
              --help) show_help; exit 0 ;;
              *) echo "Unknown option: $1"; show_help; exit 1 ;;
          esac
      done

      [ -z "$ACTION" ] || [ -z "$TARGET_IP" ] && { show_help; exit 1; }

      # Validate IP format
      echo "$TARGET_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$' || {
          echo "Error: Invalid IP address: $TARGET_IP"; exit 1;
      }

      case $ACTION in
          send)
              [ ! -f "$FISH_HISTORY_PATH" ] && { echo "Error: Fish history not found at $FISH_HISTORY_PATH"; exit 1; }

              # Calculate file size
              echo "Calculating Fish history size..."
              SOURCE_SIZE=$(${coreutils}/bin/du -sb "$FISH_HISTORY_PATH" | ${coreutils}/bin/cut -f1)
              SOURCE_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$FISH_HISTORY_PATH" | ${coreutils}/bin/cut -f1)
              echo "Fish history size: $SOURCE_SIZE_HUMAN ($SOURCE_SIZE bytes)"

              echo "Sending Fish history to $TARGET_IP..."
              if [ -n "$DRY_RUN" ]; then
                  echo "DRY RUN: Would transfer Fish history"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" $DRY_RUN "$FISH_HISTORY_PATH" "$TARGET_IP:.local/share/fish/"
              else
                  # Ensure target directory exists and transfer
                  ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.local/share/fish"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --stats "$FISH_HISTORY_PATH" "$TARGET_IP:.local/share/fish/"
              fi
              ;;
          receive)
              mkdir -p "$(dirname "$FISH_HISTORY_PATH")"

              # Calculate remote file size
              echo "Calculating remote Fish history size..."
              REMOTE_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.local/share/fish/fish_history 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_SIZE" -gt 0 ]; then
                  REMOTE_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/.local/share/fish/fish_history | cut -f1")
                  echo "Remote Fish history size: $REMOTE_SIZE_HUMAN ($REMOTE_SIZE bytes)"

                  echo "Receiving Fish history from $TARGET_IP..."
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --stats $DRY_RUN "$TARGET_IP:.local/share/fish/fish_history" "$FISH_HISTORY_PATH"
              else
                  echo "No Fish history found on remote host $TARGET_IP"
              fi
              ;;
          merge)
              mkdir -p "$(dirname "$FISH_HISTORY_PATH")"

              # Download remote history to temporary file
              echo "Downloading remote Fish history..."
              TEMP_REMOTE=$(mktemp)
              if ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 $DRY_RUN "$TARGET_IP:.local/share/fish/fish_history" "$TEMP_REMOTE" 2>/dev/null; then
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would merge local and remote Fish histories"
                  else
                      # Create backup of local history with hostname
                      LOCAL_HOSTNAME=$(${coreutils}/bin/hostname)
                      [ -f "$FISH_HISTORY_PATH" ] && cp "$FISH_HISTORY_PATH" "$FISH_HISTORY_PATH.$LOCAL_HOSTNAME.backup"

                      # Merge histories
                      merge_fish_histories "$FISH_HISTORY_PATH" "$TEMP_REMOTE" "$FISH_HISTORY_PATH"

                      # Upload merged result back to remote and create backup with remote hostname
                      echo "Uploading merged history to remote host..."
                      REMOTE_HOSTNAME=$(${openssh}/bin/ssh -A "$TARGET_IP" "hostname")
                      ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.local/share/fish && cp ~/.local/share/fish/fish_history ~/.local/share/fish/fish_history.$REMOTE_HOSTNAME.backup 2>/dev/null || true"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" "$FISH_HISTORY_PATH" "$TARGET_IP:.local/share/fish/"

                      echo "Both local and remote histories updated with merged result"
                  fi
              else
                  echo "No Fish history found on remote host $TARGET_IP"
              fi
              rm -f "$TEMP_REMOTE"
              ;;
      esac
      echo "Fish history operation completed!"
    '')
  ];
}