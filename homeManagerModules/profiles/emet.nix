{ config, pkgs, lib, ... }:

{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      # Core packages moved to general bundle
      # Nextcloud integration
      nextcloud-client
      
      # App data transfer scripts
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
            if [ "$host" = "local" ]; then
                if ${procps}/bin/pgrep -x "signal-desktop" >/dev/null 2>&1; then
                    echo "Error: Signal is running locally. Close Signal before transfer."
                    return 1
                fi
            else
                if ${openssh}/bin/ssh "$host" "${procps}/bin/pgrep -x signal-desktop >/dev/null 2>&1"; then
                    echo "Error: Signal is running on $host. Close Signal on target before transfer."
                    return 1
                fi
            fi
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
                check_signal_running "local" && check_signal_running "$TARGET_IP" || exit 1
                [ ! -d "$APP_PATH" ] && { echo "Error: Signal profile not found at $APP_PATH"; exit 1; }
                echo "Sending Signal profile to $TARGET_IP..."
                if [ -n "$DRY_RUN" ]; then
                    echo "DRY RUN: Would stop Signal on $TARGET_IP, transfer data, and ensure target directory exists"
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$APP_PATH/" "$TARGET_IP:.config/Signal/"
                else
                    # Ensure target directory exists and transfer
                    ${openssh}/bin/ssh "$TARGET_IP" "mkdir -p ~/.config"
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete "$APP_PATH/" "$TARGET_IP:.config/Signal/"
                fi
                ;;
            receive)
                check_signal_running "local" && check_signal_running "$TARGET_IP" || exit 1
                mkdir -p "$(dirname "$APP_PATH")"
                echo "Receiving Signal profile from $TARGET_IP..."
                ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$TARGET_IP:.config/Signal/" "$APP_PATH/"
                ;;
        esac
        echo "Transfer completed!"
      '')
      
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
            if [ "$host" = "local" ]; then
                if ${procps}/bin/pgrep -x "msedge\|microsoft-edge" >/dev/null 2>&1; then
                    echo "Error: Edge is running locally. Close Edge before transfer."
                    return 1
                fi
            else
                if ${openssh}/bin/ssh "$host" "${procps}/bin/pgrep -x 'msedge\|microsoft-edge' >/dev/null 2>&1"; then
                    echo "Error: Edge is running on $host. Close Edge on target before transfer."
                    return 1
                fi
            fi
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
                check_edge_running "local" && check_edge_running "$TARGET_IP" || exit 1
                [ ! -d "$APP_PATH" ] && { echo "Error: Edge profile not found at $APP_PATH"; exit 1; }
                echo "Sending Edge profile to $TARGET_IP..."
                if [ -n "$DRY_RUN" ]; then
                    echo "DRY RUN: Would stop Edge on $TARGET_IP, transfer data, and ensure target directory exists"
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$APP_PATH/" "$TARGET_IP:.config/microsoft-edge/"
                else
                    # Ensure target directory exists and transfer
                    ${openssh}/bin/ssh "$TARGET_IP" "mkdir -p ~/.config"
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete "$APP_PATH/" "$TARGET_IP:.config/microsoft-edge/"
                fi
                ;;
            receive)
                check_edge_running "local" && check_edge_running "$TARGET_IP" || exit 1
                mkdir -p "$(dirname "$APP_PATH")"
                echo "Receiving Edge profile from $TARGET_IP..."
                ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$TARGET_IP:.config/microsoft-edge/" "$APP_PATH/"
                ;;
        esac
        echo "Transfer completed!"
      '')
    ];
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };


  # Enable emet's preferred bundles by default
  myHomeManager = {
    # Bundles
    bundles.general.enable = true;
    bundles.desktop.enable = true;
    bundles.desktop-full.enable = true;
    bundles.gaming.enable = true;
    bundles.databender.enable = true;  # Can be overridden per host

    # Features
    fish.enable = false;  # Explicitly disable fish
    zsh.enable = false;   # Disable zsh - not used
    kitty.enable = true;
    firefox.enable = true;
    hyprland.enable = lib.mkDefault true;
    # Conditional desktop components - only if Hyprland is enabled
    waybar.enable = lib.mkIf config.myHomeManager.hyprland.enable (lib.mkDefault true);
  };

  programs = {
    home-manager.enable = true;

    nix-index = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
