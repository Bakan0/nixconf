{ config, lib, pkgs, ... }:
with pkgs;
{
  home.packages = [
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
              REMOTE_ZETTEL_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/zettelkasten 2>/dev/null | cut -f1" || echo 0)
              REMOTE_CONFIG_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "du -sb ~/.config/zettelkasten 2>/dev/null | cut -f1" || echo 0)

              # Ensure variables are valid integers
              REMOTE_ZETTEL_SIZE=''${REMOTE_ZETTEL_SIZE:-0}
              REMOTE_CONFIG_SIZE=''${REMOTE_CONFIG_SIZE:-0}

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
  ];
}