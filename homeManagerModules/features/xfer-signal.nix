{ config, lib, pkgs, ... }:
with pkgs;
{
  home.packages = [
    (writeShellScriptBin "xfer-signal" ''
      set -euo pipefail

      APP_PATH="$HOME/.config/Signal"

      show_help() {
          echo "Usage: xfer-signal [--send|--receive] <target_ip> [--dry-run]"
          echo "Transfer Signal Desktop profile between hosts using zstd+rsync"
          echo ""
          echo "Notes:"
          echo "  - Transfers complete Signal profile including messages and settings"
          echo "  - You'll need to re-link Signal after receiving on new machine"
          echo "  - Never run Signal on both machines simultaneously after transfer"
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

              echo ""
              echo "Transfer complete! Signal will prompt for re-linking on first launch."
              ;;
      esac
      echo "Transfer completed!"
    '')
  ];
}