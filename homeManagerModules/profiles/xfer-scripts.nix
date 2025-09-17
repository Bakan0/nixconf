{ config, pkgs, lib, ... }:

with pkgs;

{
  home.packages = [
    # Signal Desktop transfer script
    (writeShellScriptBin "xfer-signal" ''
      set -euo pipefail

      APP_PATH="$HOME/.config/Signal"

      show_help() {
          echo "Usage: xfer-signal [--send|--receive] <target_ip> [--dry-run]"
          echo "Transfer Signal Desktop profile between hosts using zstd+rsync"
          echo ""
          echo "Examples:"
          echo "  xfer-signal --send 10.17.19.89"
          echo "  xfer-signal --receive 10.17.19.89 --dry-run"
      }

      check_signal_running() {
          local host="$1"
          local host_name="$2"
          if [ "$host" = "local" ]; then
              ${procps}/bin/pgrep -f "signal-desktop\|electron.*Signal" >/dev/null 2>&1
          else
              ${openssh}/bin/ssh -A "$host" "${procps}/bin/pgrep -f 'signal-desktop\|electron.*Signal' >/dev/null 2>&1"
          fi
      }

      wait_for_signal_closure() {
          local target_ip="$1"
          while true; do
              local local_running=false
              local remote_running=false

              if check_signal_running "local" "local"; then
                  local_running=true
              fi

              if check_signal_running "$target_ip" "remote"; then
                  remote_running=true
              fi

              if [ "$local_running" = false ] && [ "$remote_running" = false ]; then
                  break
              fi

              # Show which hosts have Signal running
              echo "Signal is currently running on:"
              if [ "$local_running" = true ]; then
                  echo "  - Local machine ($(hostname))"
              fi
              if [ "$remote_running" = true ]; then
                  echo "  - Remote machine ($target_ip)"
              fi
              echo "Please quit Signal on the above machine(s) before continuing."
              echo "Press Enter to check again, or Ctrl+C to cancel..."
              read -r
              sleep 1
          done
      }

      # Parse arguments
      ACTION=""
      TARGET_IP=""
      DRY_RUN=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              --send) ACTION="send"; TARGET_IP="$2"; shift 2 ;;
              --receive) ACTION="receive"; TARGET_IP="$2"; shift 2 ;;
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
              [ ! -d "$APP_PATH" ] && { echo "Error: Signal profile not found at $APP_PATH"; exit 1; }

              # Wait for Signal to be closed on both machines
              wait_for_signal_closure "$TARGET_IP"

              # Calculate initial directory size
              echo "Calculating Signal profile size..."
              SOURCE_SIZE=$(${coreutils}/bin/du -sb "$APP_PATH" | ${coreutils}/bin/cut -f1)
              SOURCE_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$APP_PATH" | ${coreutils}/bin/cut -f1)
              echo "Signal profile size: $SOURCE_SIZE_HUMAN ($SOURCE_SIZE bytes)"

              echo "Sending Signal profile to $TARGET_IP..."
              if [ -n "$DRY_RUN" ]; then
                  echo "DRY RUN: Would transfer data and ensure target directory exists"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete -e "ssh -A" $DRY_RUN "$APP_PATH/" "$TARGET_IP:.config/Signal/"
              else
                  # Ensure target directory exists and transfer
                  ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.config"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats -e "ssh -A" "$APP_PATH/" "$TARGET_IP:.config/Signal/"
              fi
              ;;
          receive)
              mkdir -p "$(dirname "$APP_PATH")"

              # Wait for Signal to be closed on both machines
              wait_for_signal_closure "$TARGET_IP"

              # Calculate remote directory size
              echo "Calculating remote Signal profile size..."
              REMOTE_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.config/Signal 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_SIZE" -gt 0 ]; then
                  REMOTE_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/.config/Signal | cut -f1")
                  echo "Remote Signal profile size: $REMOTE_SIZE_HUMAN ($REMOTE_SIZE bytes)"
              fi

              echo "Receiving Signal profile from $TARGET_IP..."
              ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats -e "ssh -A" $DRY_RUN "$TARGET_IP:.config/Signal/" "$APP_PATH/"
              ;;
      esac
      echo "Transfer completed!"
    '')

    # Microsoft Edge transfer script
    (writeShellScriptBin "xfer-edge" ''
      set -euo pipefail

      APP_PATH="$HOME/.config/microsoft-edge"

      show_help() {
          echo "Usage: xfer-edge [--send|--receive] <target_ip> [--dry-run]"
          echo "Transfer Microsoft Edge profile between hosts using zstd+rsync"
          echo "Note: For GCCH environments without sync capability"
          echo ""
          echo "Examples:"
          echo "  xfer-edge --send 10.17.19.89"
          echo "  xfer-edge --receive 10.17.19.89 --dry-run"
      }

      check_edge_running() {
          local host="$1"
          local host_name="$2"
          if [ "$host" = "local" ]; then
              ${procps}/bin/pgrep -f "msedge\|microsoft-edge\|edge" >/dev/null 2>&1
          else
              ${openssh}/bin/ssh "$host" "${procps}/bin/pgrep -f 'msedge\|microsoft-edge\|edge' >/dev/null 2>&1"
          fi
      }

      wait_for_edge_closure() {
          local target_ip="$1"
          while true; do
              local local_running=false
              local remote_running=false

              if check_edge_running "local" "local"; then
                  local_running=true
              fi

              if check_edge_running "$target_ip" "remote"; then
                  remote_running=true
              fi

              if [ "$local_running" = false ] && [ "$remote_running" = false ]; then
                  break
              fi

              # Show which hosts have Edge running
              echo "Microsoft Edge is currently running on:"
              if [ "$local_running" = true ]; then
                  echo "  - Local machine ($(hostname))"
              fi
              if [ "$remote_running" = true ]; then
                  echo "  - Remote machine ($target_ip)"
              fi
              echo "Please quit Edge on the above machine(s) before continuing."
              echo "Press Enter to check again, or Ctrl+C to cancel..."
              read -r
              sleep 1
          done
      }

      # Parse arguments
      ACTION=""
      TARGET_IP=""
      DRY_RUN=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              --send) ACTION="send"; TARGET_IP="$2"; shift 2 ;;
              --receive) ACTION="receive"; TARGET_IP="$2"; shift 2 ;;
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
              [ ! -d "$APP_PATH" ] && { echo "Error: Edge profile not found at $APP_PATH"; exit 1; }

              # Wait for Edge to be closed on both machines
              wait_for_edge_closure "$TARGET_IP"

              # Calculate initial directory size
              echo "Calculating Edge profile size..."
              SOURCE_SIZE=$(${coreutils}/bin/du -sb "$APP_PATH" | ${coreutils}/bin/cut -f1)
              SOURCE_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$APP_PATH" | ${coreutils}/bin/cut -f1)
              echo "Edge profile size: $SOURCE_SIZE_HUMAN ($SOURCE_SIZE bytes)"

              echo "Sending Edge profile to $TARGET_IP..."
              if [ -n "$DRY_RUN" ]; then
                  echo "DRY RUN: Would transfer data and ensure target directory exists"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete -e "ssh -A" $DRY_RUN "$APP_PATH/" "$TARGET_IP:.config/microsoft-edge/"
              else
                  # Ensure target directory exists and transfer
                  ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.config"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats -e "ssh -A" "$APP_PATH/" "$TARGET_IP:.config/microsoft-edge/"
              fi
              ;;
          receive)
              mkdir -p "$(dirname "$APP_PATH")"

              # Wait for Edge to be closed on both machines
              wait_for_edge_closure "$TARGET_IP"

              # Calculate remote directory size
              echo "Calculating remote Edge profile size..."
              REMOTE_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.config/microsoft-edge 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_SIZE" -gt 0 ]; then
                  REMOTE_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/.config/microsoft-edge | cut -f1")
                  echo "Remote Edge profile size: $REMOTE_SIZE_HUMAN ($REMOTE_SIZE bytes)"
              fi

              echo "Receiving Edge profile from $TARGET_IP..."
              ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats -e "ssh -A" $DRY_RUN "$TARGET_IP:.config/microsoft-edge/" "$APP_PATH/"
              ;;
      esac
      echo "Transfer completed!"
    '')

    # Fish history transfer script
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

    # Obsidian/Zettelkasten transfer script
    (writeShellScriptBin "xfer-obsidian" ''
      set -euo pipefail

      ZETTEL_PATH="$HOME/zettelkasten"
      CONFIG_PATH="$HOME/.config/zettelkasten"

      show_help() {
          echo "Usage: xfer-obsidian [--send|--receive] <target_ip> [--dry-run]"
          echo "Transfer Obsidian notes and config between hosts using zstd+rsync"
          echo ""
          echo "Transfers:"
          echo "  ~/zettelkasten (notes directory)"
          echo "  ~/.config/zettelkasten (Obsidian config)"
          echo ""
          echo "Examples:"
          echo "  xfer-obsidian --send 10.17.19.89"
          echo "  xfer-obsidian --receive 10.17.19.89 --dry-run"
      }

      check_obsidian_running() {
          local host="$1"
          local host_name="$2"
          if [ "$host" = "local" ]; then
              ${procps}/bin/pgrep -f "obsidian\|logseq\|zettlr\|notion\|roam\|remnote\|electron.*obsidian" >/dev/null 2>&1
          else
              ${openssh}/bin/ssh "$host" "${procps}/bin/pgrep -f 'obsidian\|logseq\|zettlr\|notion\|roam\|remnote\|electron.*obsidian' >/dev/null 2>&1"
          fi
      }

      wait_for_obsidian_closure() {
          local target_ip="$1"
          while true; do
              local local_running=false
              local remote_running=false

              if check_obsidian_running "local" "local"; then
                  local_running=true
              fi

              if check_obsidian_running "$target_ip" "remote"; then
                  remote_running=true
              fi

              if [ "$local_running" = false ] && [ "$remote_running" = false ]; then
                  break
              fi

              # Show which hosts have Obsidian running
              echo "Obsidian is currently running on:"
              if [ "$local_running" = true ]; then
                  echo "  - Local machine ($(hostname))"
              fi
              if [ "$remote_running" = true ]; then
                  echo "  - Remote machine ($target_ip)"
              fi
              echo "Please quit Obsidian on the above machine(s) before continuing."
              echo "Press Enter to check again, or Ctrl+C to cancel..."
              read -r
              sleep 1
          done
      }

      # Parse arguments
      ACTION=""
      TARGET_IP=""
      DRY_RUN=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              --send) ACTION="send"; TARGET_IP="$2"; shift 2 ;;
              --receive) ACTION="receive"; TARGET_IP="$2"; shift 2 ;;
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
              # Check if at least one directory exists
              if [ ! -d "$ZETTEL_PATH" ] && [ ! -d "$CONFIG_PATH" ]; then
                  echo "Error: Neither $ZETTEL_PATH nor $CONFIG_PATH found"
                  exit 1
              fi

              # Wait for Obsidian to be closed on both machines
              wait_for_obsidian_closure "$TARGET_IP"

              # Calculate sizes for existing directories
              if [ -d "$ZETTEL_PATH" ]; then
                  ZETTEL_SIZE=$(${coreutils}/bin/du -sb "$ZETTEL_PATH" | ${coreutils}/bin/cut -f1)
                  ZETTEL_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$ZETTEL_PATH" | ${coreutils}/bin/cut -f1)
                  echo "Zettelkasten notes size: $ZETTEL_SIZE_HUMAN ($ZETTEL_SIZE bytes)"
              fi

              if [ -d "$CONFIG_PATH" ]; then
                  CONFIG_SIZE=$(${coreutils}/bin/du -sb "$CONFIG_PATH" | ${coreutils}/bin/cut -f1)
                  CONFIG_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$CONFIG_PATH" | ${coreutils}/bin/cut -f1)
                  echo "Zettelkasten config size: $CONFIG_SIZE_HUMAN ($CONFIG_SIZE bytes)"
              fi

              # Transfer notes directory
              if [ -d "$ZETTEL_PATH" ]; then
                  echo "Sending Zettelkasten notes to $TARGET_IP..."
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would transfer notes directory"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$ZETTEL_PATH/" "$TARGET_IP:zettelkasten/"
                  else
                      ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/zettelkasten"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$ZETTEL_PATH/" "$TARGET_IP:zettelkasten/"
                  fi
              fi

              # Transfer config directory
              if [ -d "$CONFIG_PATH" ]; then
                  echo "Sending Zettelkasten config to $TARGET_IP..."
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would transfer config directory"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$CONFIG_PATH/" "$TARGET_IP:.config/zettelkasten/"
                  else
                      ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.config/zettelkasten"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$CONFIG_PATH/" "$TARGET_IP:.config/zettelkasten/"
                  fi
              fi
              ;;

          receive)
              mkdir -p "$(dirname "$ZETTEL_PATH")" "$(dirname "$CONFIG_PATH")"

              # Wait for Obsidian to be closed on both machines
              wait_for_obsidian_closure "$TARGET_IP"

              # Calculate remote sizes
              echo "Checking remote Zettelkasten sizes..."
              REMOTE_ZETTEL_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/zettelkasten 2>/dev/null | cut -f1 || echo 0")
              REMOTE_CONFIG_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.config/zettelkasten 2>/dev/null | cut -f1 || echo 0")

              if [ "$REMOTE_ZETTEL_SIZE" -gt 0 ]; then
                  REMOTE_ZETTEL_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/zettelkasten | cut -f1")
                  echo "Remote Zettelkasten notes size: $REMOTE_ZETTEL_SIZE_HUMAN ($REMOTE_ZETTEL_SIZE bytes)"

                  echo "Receiving Zettelkasten notes from $TARGET_IP..."
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:zettelkasten/" "$ZETTEL_PATH/"
              fi

              if [ "$REMOTE_CONFIG_SIZE" -gt 0 ]; then
                  REMOTE_CONFIG_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/.config/zettelkasten | cut -f1")
                  echo "Remote Zettelkasten config size: $REMOTE_CONFIG_SIZE_HUMAN ($REMOTE_CONFIG_SIZE bytes)"

                  echo "Receiving Zettelkasten config from $TARGET_IP..."
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:.config/zettelkasten/" "$CONFIG_PATH/"
              fi

              if [ "$REMOTE_ZETTEL_SIZE" -eq 0 ] && [ "$REMOTE_CONFIG_SIZE" -eq 0 ]; then
                  echo "No Zettelkasten data found on remote host $TARGET_IP"
              fi
              ;;
      esac
      echo "Zettelkasten transfer completed!"
    '')

    # Libvirt VM transfer script
    (writeShellScriptBin "xfer-libvirt" ''
      set -euo pipefail

      # Libvirt paths - typical locations
      VM_IMAGES_PATH="/var/lib/libvirt/images"
      VM_CONFIGS_PATH="/etc/libvirt/qemu"
      NETWORK_CONFIGS_PATH="/etc/libvirt/qemu/networks"
      USER_CONFIGS_PATH="$HOME/.config/libvirt"

      show_help() {
          echo "Usage: xfer-libvirt [--send|--receive] <target_ip> [--dry-run]"
          echo "Transfer libvirt VMs and configurations between hosts using zstd+rsync"
          echo ""
          echo "Transfers:"
          echo "  /var/lib/libvirt/images (VM disk images - qcow2, raw, etc.)"
          echo "  /etc/libvirt/qemu (VM XML configurations)"
          echo "  /etc/libvirt/qemu/networks (network configurations)"
          echo "  ~/.config/libvirt (user-specific libvirt config)"
          echo ""
          echo "Examples:"
          echo "  xfer-libvirt --send 10.17.19.89"
          echo "  xfer-libvirt --receive 10.17.19.89 --dry-run"
          echo ""
          echo "Note: Requires sudo for system directories. VMs should be shut down before transfer."
      }

      check_libvirt_running() {
          local host="$1"
          if [ "$host" = "local" ]; then
              # Check for running VMs
              sudo virsh list --state-running 2>/dev/null | grep -q "running" || return 1
          else
              ${openssh}/bin/ssh -t "$host" "sudo virsh list --state-running 2>/dev/null | grep -q 'running'" || return 1
          fi
      }

      wait_for_vm_shutdown() {
          local target_ip="$1"
          while true; do
              local local_running=false
              local remote_running=false

              if check_libvirt_running "local"; then
                  local_running=true
              fi

              if check_libvirt_running "$target_ip"; then
                  remote_running=true
              fi

              if [ "$local_running" = false ] && [ "$remote_running" = false ]; then
                  break
              fi

              echo "Running VMs detected on:"
              if [ "$local_running" = true ]; then
                  echo "  - Local machine ($(hostname))"
                  sudo virsh list --state-running 2>/dev/null | grep running | awk '{print "    * " $2}'
              fi
              if [ "$remote_running" = true ]; then
                  echo "  - Remote machine ($target_ip)"
                  ${openssh}/bin/ssh -t "$target_ip" "sudo virsh list --state-running 2>/dev/null | grep running | awk '{print \"    * \" \$2}'"
              fi
              echo "Please shut down all VMs before continuing."
              echo "Press Enter to check again, or Ctrl+C to cancel..."
              read -r
              sleep 1
          done
      }

      # Parse arguments
      ACTION=""
      TARGET_IP=""
      DRY_RUN=""

      while [[ $# -gt 0 ]]; do
          case $1 in
              --send) ACTION="send"; TARGET_IP="$2"; shift 2 ;;
              --receive) ACTION="receive"; TARGET_IP="$2"; shift 2 ;;
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
              # Check if libvirt is installed and directories exist
              if [ ! -d "$VM_IMAGES_PATH" ] && [ ! -d "$VM_CONFIGS_PATH" ] && [ ! -d "$USER_CONFIGS_PATH" ]; then
                  echo "Error: No libvirt directories found. Is libvirt installed?"
                  exit 1
              fi

              # Wait for VMs to be shut down
              wait_for_vm_shutdown "$TARGET_IP"

              # Calculate sizes for existing directories
              echo "Calculating libvirt data sizes..."
              if [ -d "$VM_IMAGES_PATH" ] && [ "$(sudo ls -A "$VM_IMAGES_PATH" 2>/dev/null)" ]; then
                  IMAGES_SIZE=$(sudo ${coreutils}/bin/du -sb "$VM_IMAGES_PATH" | ${coreutils}/bin/cut -f1)
                  IMAGES_SIZE_HUMAN=$(sudo ${coreutils}/bin/du -sh "$VM_IMAGES_PATH" | ${coreutils}/bin/cut -f1)
                  echo "VM images size: $IMAGES_SIZE_HUMAN ($IMAGES_SIZE bytes)"
              fi

              if [ -d "$VM_CONFIGS_PATH" ] && [ "$(sudo ls -A "$VM_CONFIGS_PATH" 2>/dev/null)" ]; then
                  CONFIGS_SIZE=$(sudo ${coreutils}/bin/du -sb "$VM_CONFIGS_PATH" | ${coreutils}/bin/cut -f1)
                  CONFIGS_SIZE_HUMAN=$(sudo ${coreutils}/bin/du -sh "$VM_CONFIGS_PATH" | ${coreutils}/bin/cut -f1)
                  echo "VM configs size: $CONFIGS_SIZE_HUMAN ($CONFIGS_SIZE bytes)"
              fi

              if [ -d "$NETWORK_CONFIGS_PATH" ] && [ "$(sudo ls -A "$NETWORK_CONFIGS_PATH" 2>/dev/null)" ]; then
                  NETWORK_SIZE=$(sudo ${coreutils}/bin/du -sb "$NETWORK_CONFIGS_PATH" | ${coreutils}/bin/cut -f1)
                  NETWORK_SIZE_HUMAN=$(sudo ${coreutils}/bin/du -sh "$NETWORK_CONFIGS_PATH" | ${coreutils}/bin/cut -f1)
                  echo "Network configs size: $NETWORK_SIZE_HUMAN ($NETWORK_SIZE bytes)"
              fi

              if [ -d "$USER_CONFIGS_PATH" ] && [ "$(ls -A "$USER_CONFIGS_PATH" 2>/dev/null)" ]; then
                  USER_SIZE=$(${coreutils}/bin/du -sb "$USER_CONFIGS_PATH" | ${coreutils}/bin/cut -f1)
                  USER_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$USER_CONFIGS_PATH" | ${coreutils}/bin/cut -f1)
                  echo "User configs size: $USER_SIZE_HUMAN ($USER_SIZE bytes)"
              fi

              # Transfer VM images (largest files first)
              if [ -d "$VM_IMAGES_PATH" ] && [ "$(sudo ls -A "$VM_IMAGES_PATH" 2>/dev/null)" ]; then
                  echo "Sending VM images to $TARGET_IP..."
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would transfer VM images"
                      sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$VM_IMAGES_PATH/" "$TARGET_IP:/var/lib/libvirt/images/"
                  else
                      ${openssh}/bin/ssh -At "$TARGET_IP" "sudo mkdir -p /var/lib/libvirt/images"
                      sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$VM_IMAGES_PATH/" "$TARGET_IP:/var/lib/libvirt/images/"
                  fi
              fi

              # Transfer VM configurations
              if [ -d "$VM_CONFIGS_PATH" ] && [ "$(sudo ls -A "$VM_CONFIGS_PATH" 2>/dev/null)" ]; then
                  echo "Sending VM configurations to $TARGET_IP..."
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would transfer VM configurations"
                      sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$VM_CONFIGS_PATH/" "$TARGET_IP:/etc/libvirt/qemu/"
                  else
                      ${openssh}/bin/ssh -At "$TARGET_IP" "sudo mkdir -p /etc/libvirt/qemu"
                      sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$VM_CONFIGS_PATH/" "$TARGET_IP:/etc/libvirt/qemu/"
                  fi
              fi

              # Transfer network configurations
              if [ -d "$NETWORK_CONFIGS_PATH" ] && [ "$(sudo ls -A "$NETWORK_CONFIGS_PATH" 2>/dev/null)" ]; then
                  echo "Sending network configurations to $TARGET_IP..."
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would transfer network configurations"
                      sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$NETWORK_CONFIGS_PATH/" "$TARGET_IP:/etc/libvirt/qemu/networks/"
                  else
                      ${openssh}/bin/ssh -At "$TARGET_IP" "sudo mkdir -p /etc/libvirt/qemu/networks"
                      sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$NETWORK_CONFIGS_PATH/" "$TARGET_IP:/etc/libvirt/qemu/networks/"
                  fi
              fi

              # Transfer user configurations
              if [ -d "$USER_CONFIGS_PATH" ] && [ "$(ls -A "$USER_CONFIGS_PATH" 2>/dev/null)" ]; then
                  echo "Sending user libvirt config to $TARGET_IP..."
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would transfer user configurations"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$USER_CONFIGS_PATH/" "$TARGET_IP:.config/libvirt/"
                  else
                      ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.config/libvirt"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$USER_CONFIGS_PATH/" "$TARGET_IP:.config/libvirt/"
                  fi
              fi

              echo "Post-transfer instructions:"
              echo "1. On destination host, restart libvirt: sudo systemctl restart libvirtd"
              echo "2. Redefine VMs: sudo virsh define /etc/libvirt/qemu/<vm-name>.xml"
              echo "3. Start networks: sudo virsh net-start <network-name>"
              echo "4. Verify with: sudo virsh list --all && sudo virsh net-list --all"
              ;;

          receive)
              mkdir -p "$(dirname "$USER_CONFIGS_PATH")"

              # Wait for VMs to be shut down
              wait_for_vm_shutdown "$TARGET_IP"

              echo "Checking remote libvirt data sizes..."

              # Check and receive VM images
              REMOTE_IMAGES_SIZE=$(${openssh}/bin/ssh -At "$TARGET_IP" "sudo du -sb /var/lib/libvirt/images 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_IMAGES_SIZE" -gt 0 ]; then
                  REMOTE_IMAGES_SIZE_HUMAN=$(${openssh}/bin/ssh -At "$TARGET_IP" "sudo du -sh /var/lib/libvirt/images | cut -f1")
                  echo "Remote VM images size: $REMOTE_IMAGES_SIZE_HUMAN ($REMOTE_IMAGES_SIZE bytes)"

                  echo "Receiving VM images from $TARGET_IP..."
                  sudo mkdir -p "$VM_IMAGES_PATH"
                  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:/var/lib/libvirt/images/" "$VM_IMAGES_PATH/"
              fi

              # Check and receive VM configurations
              REMOTE_CONFIGS_SIZE=$(${openssh}/bin/ssh -At "$TARGET_IP" "sudo du -sb /etc/libvirt/qemu 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_CONFIGS_SIZE" -gt 0 ]; then
                  REMOTE_CONFIGS_SIZE_HUMAN=$(${openssh}/bin/ssh -At "$TARGET_IP" "sudo du -sh /etc/libvirt/qemu | cut -f1")
                  echo "Remote VM configs size: $REMOTE_CONFIGS_SIZE_HUMAN ($REMOTE_CONFIGS_SIZE bytes)"

                  echo "Receiving VM configurations from $TARGET_IP..."
                  sudo mkdir -p "$VM_CONFIGS_PATH"
                  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:/etc/libvirt/qemu/" "$VM_CONFIGS_PATH/"
              fi

              # Check and receive network configurations
              REMOTE_NETWORK_SIZE=$(${openssh}/bin/ssh -At "$TARGET_IP" "sudo du -sb /etc/libvirt/qemu/networks 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_NETWORK_SIZE" -gt 0 ]; then
                  REMOTE_NETWORK_SIZE_HUMAN=$(${openssh}/bin/ssh -At "$TARGET_IP" "sudo du -sh /etc/libvirt/qemu/networks | cut -f1")
                  echo "Remote network configs size: $REMOTE_NETWORK_SIZE_HUMAN ($REMOTE_NETWORK_SIZE bytes)"

                  echo "Receiving network configurations from $TARGET_IP..."
                  sudo mkdir -p "$NETWORK_CONFIGS_PATH"
                  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:/etc/libvirt/qemu/networks/" "$NETWORK_CONFIGS_PATH/"
              fi

              # Check and receive user configurations
              REMOTE_USER_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.config/libvirt 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_USER_SIZE" -gt 0 ]; then
                  REMOTE_USER_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/.config/libvirt | cut -f1")
                  echo "Remote user configs size: $REMOTE_USER_SIZE_HUMAN ($REMOTE_USER_SIZE bytes)"

                  echo "Receiving user libvirt config from $TARGET_IP..."
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:.config/libvirt/" "$USER_CONFIGS_PATH/"
              fi

              if [ "$REMOTE_IMAGES_SIZE" -eq 0 ] && [ "$REMOTE_CONFIGS_SIZE" -eq 0 ] && [ "$REMOTE_NETWORK_SIZE" -eq 0 ] && [ "$REMOTE_USER_SIZE" -eq 0 ]; then
                  echo "No libvirt data found on remote host $TARGET_IP"
              fi

              echo "Post-transfer instructions:"
              echo "1. Restart libvirt: sudo systemctl restart libvirtd"
              echo "2. Redefine VMs: sudo virsh define /etc/libvirt/qemu/<vm-name>.xml"
              echo "3. Start networks: sudo virsh net-start <network-name>"
              echo "4. Verify with: sudo virsh list --all && sudo virsh net-list --all"
              ;;
      esac
      echo "Libvirt transfer completed!"
    '')

    # Claude Code transfer script
    (writeShellScriptBin "xfer-claude" ''
      set -euo pipefail

      CLAUDE_PATH="$HOME/.claude"

      show_help() {
          echo "Usage: xfer-claude [--send|--receive|--merge] <target_ip> [--dry-run]"
          echo "Transfer Claude Code configuration and conversations between hosts using zstd+rsync"
          echo ""
          echo "Operations:"
          echo "  --send     Replace remote Claude data with local Claude data"
          echo "  --receive  Replace local Claude data with remote Claude data"
          echo "  --merge    Intelligently merge local and remote conversation histories"
          echo ""
          echo "Transfers:"
          echo "  ~/.claude/projects (conversation histories organized by project)"
          echo "  ~/.claude/settings.json (Claude Code settings)"
          echo "  ~/.claude/settings.local.json (local settings)"
          echo "  ~/.claude/.credentials.json (API credentials)"
          echo "  ~/.claude/todos (todo lists from conversations)"
          echo ""
          echo "Examples:"
          echo "  xfer-claude --send 10.17.19.89"
          echo "  xfer-claude --receive 10.17.19.89 --dry-run"
          echo "  xfer-claude --merge 10.17.19.89"
      }

      check_claude_running() {
          local host="$1"
          if [ "$host" = "local" ]; then
              ${procps}/bin/pgrep -f "code.*claude\|claude" >/dev/null 2>&1
          else
              ${openssh}/bin/ssh "$host" "${procps}/bin/pgrep -f 'code.*claude\|claude' >/dev/null 2>&1"
          fi
      }

      wait_for_claude_closure() {
          local target_ip="$1"
          while true; do
              local local_running=false
              local remote_running=false

              if check_claude_running "local"; then
                  local_running=true
              fi

              if check_claude_running "$target_ip"; then
                  remote_running=true
              fi

              if [ "$local_running" = false ] && [ "$remote_running" = false ]; then
                  break
              fi

              echo "Claude Code is currently running on:"
              if [ "$local_running" = true ]; then
                  echo "  - Local machine ($(hostname))"
              fi
              if [ "$remote_running" = true ]; then
                  echo "  - Remote machine ($target_ip)"
              fi
              echo "Please quit Claude Code/VSCode on the above machine(s) before continuing."
              echo "Press Enter to check again, or Ctrl+C to cancel..."
              read -r
              sleep 1
          done
      }

      merge_claude_projects() {
          local local_dir="$1"
          local remote_dir="$2"
          local output_dir="$3"

          echo "Merging Claude project conversations..."

          # Ensure output directory exists
          mkdir -p "$output_dir"

          # Copy all local projects first (preserves all local conversations)
          if [ -d "$local_dir" ]; then
              ${rsync}/bin/rsync -a "$local_dir/" "$output_dir/"
          fi

          # Merge remote projects using a more sophisticated approach
          if [ -d "$remote_dir" ]; then
              # For each project directory in remote
              find "$remote_dir" -mindepth 1 -maxdepth 1 -type d | while read -r remote_project; do
                  project_name=$(basename "$remote_project")
                  local_project="$output_dir/$project_name"

                  echo "  Merging project: $project_name"

                  # Ensure local project directory exists
                  mkdir -p "$local_project"

                  # Copy all remote conversation files that don't exist locally
                  # This preserves unique conversations from both machines
                  ${rsync}/bin/rsync -a --ignore-existing "$remote_project/" "$local_project/"

                  # Also update any files that are newer on remote (--update)
                  ${rsync}/bin/rsync -a --update "$remote_project/" "$local_project/"
              done

              # Handle any remote project directories that don't exist locally at all
              ${rsync}/bin/rsync -a --ignore-existing "$remote_dir/" "$output_dir/"
          fi

          # Count conversations for reporting
          local total_conversations=0
          if [ -d "$output_dir" ]; then
              total_conversations=$(find "$output_dir" -name "*.json" -type f | wc -l)
          fi

          echo "Claude conversations merged successfully - Total conversations: $total_conversations"
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
              [ ! -d "$CLAUDE_PATH" ] && { echo "Error: Claude directory not found at $CLAUDE_PATH"; exit 1; }

              # Wait for Claude to be closed on both machines
              wait_for_claude_closure "$TARGET_IP"

              # Calculate directory size
              echo "Calculating Claude data size..."
              SOURCE_SIZE=$(${coreutils}/bin/du -sb "$CLAUDE_PATH" | ${coreutils}/bin/cut -f1)
              SOURCE_SIZE_HUMAN=$(${coreutils}/bin/du -sh "$CLAUDE_PATH" | ${coreutils}/bin/cut -f1)
              echo "Claude data size: $SOURCE_SIZE_HUMAN ($SOURCE_SIZE bytes)"

              echo "Sending Claude data to $TARGET_IP..."
              if [ -n "$DRY_RUN" ]; then
                  echo "DRY RUN: Would transfer Claude configuration and conversations"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete $DRY_RUN "$CLAUDE_PATH/" "$TARGET_IP:.claude/"
              else
                  # Ensure target directory exists and transfer
                  ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.claude"
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats "$CLAUDE_PATH/" "$TARGET_IP:.claude/"
              fi
              ;;
          receive)
              mkdir -p "$(dirname "$CLAUDE_PATH")"

              # Wait for Claude to be closed on both machines
              wait_for_claude_closure "$TARGET_IP"

              # Calculate remote directory size
              echo "Calculating remote Claude data size..."
              REMOTE_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.claude 2>/dev/null | cut -f1 || echo 0")
              if [ "$REMOTE_SIZE" -gt 0 ]; then
                  REMOTE_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sh ~/.claude | cut -f1")
                  echo "Remote Claude data size: $REMOTE_SIZE_HUMAN ($REMOTE_SIZE bytes)"

                  echo "Receiving Claude data from $TARGET_IP..."
                  ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:.claude/" "$CLAUDE_PATH/"
              else
                  echo "No Claude data found on remote host $TARGET_IP"
              fi
              ;;
          merge)
              mkdir -p "$(dirname "$CLAUDE_PATH")"

              # Wait for Claude to be closed on both machines
              wait_for_claude_closure "$TARGET_IP"

              # Download remote Claude data to temporary directory
              echo "Downloading remote Claude data..."
              TEMP_REMOTE=$(mktemp -d)
              if ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 $DRY_RUN "$TARGET_IP:.claude/" "$TEMP_REMOTE/" 2>/dev/null; then
                  if [ -n "$DRY_RUN" ]; then
                      echo "DRY RUN: Would merge local and remote Claude data"
                  else
                      # Create backup of local data with hostname
                      LOCAL_HOSTNAME=$(${coreutils}/bin/hostname)
                      [ -d "$CLAUDE_PATH" ] && cp -r "$CLAUDE_PATH" "$CLAUDE_PATH.$LOCAL_HOSTNAME.backup"

                      # Merge the data (prioritizing newer files for projects)
                      echo "Merging Claude configurations and conversations..."

                      # Merge projects directory specially
                      if [ -d "$CLAUDE_PATH/projects" ] || [ -d "$TEMP_REMOTE/projects" ]; then
                          merge_claude_projects "$CLAUDE_PATH/projects" "$TEMP_REMOTE/projects" "$CLAUDE_PATH/projects"
                      fi

                      # Sync other directories normally (keeping newer files)
                      for dir in settings.json settings.local.json .credentials.json todos statsig ide plugins; do
                          if [ -e "$TEMP_REMOTE/$dir" ]; then
                              if [ -e "$CLAUDE_PATH/$dir" ]; then
                                  # Use rsync --update to keep newer files
                                  ${rsync}/bin/rsync -a --update "$TEMP_REMOTE/$dir" "$CLAUDE_PATH/"
                              else
                                  # Copy if doesn't exist locally
                                  cp -r "$TEMP_REMOTE/$dir" "$CLAUDE_PATH/"
                              fi
                          fi
                      done

                      # Upload merged result back to remote and create backup with remote hostname
                      echo "Uploading merged Claude data to remote host..."
                      REMOTE_HOSTNAME=$(${openssh}/bin/ssh -A "$TARGET_IP" "hostname")
                      ${openssh}/bin/ssh -A "$TARGET_IP" "mkdir -p ~/.claude && [ -d ~/.claude ] && cp -r ~/.claude ~/.claude.$REMOTE_HOSTNAME.backup 2>/dev/null || true"
                      ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress -e "ssh -A" --delete "$CLAUDE_PATH/" "$TARGET_IP:.claude/"

                      echo "Both local and remote Claude data updated with merged result"
                  fi
              else
                  echo "No Claude data found on remote host $TARGET_IP"
              fi
              rm -rf "$TEMP_REMOTE"
              ;;
      esac
      echo "Claude data operation completed!"
    '')
  ];
}