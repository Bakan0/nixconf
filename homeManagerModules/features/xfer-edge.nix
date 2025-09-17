{ config, lib, pkgs, ... }:
with pkgs;
{
  home.packages = [
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
  ];
}