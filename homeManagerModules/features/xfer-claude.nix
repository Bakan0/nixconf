{ config, lib, pkgs, ... }:
with pkgs;
{
  home.packages = [
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