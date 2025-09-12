{ config, pkgs, lib, ... }:

{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
    };

    packages = with pkgs; [
      # Core packages moved to general bundle
      
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
            local host_name="$2"
            if [ "$host" = "local" ]; then
                ${procps}/bin/pgrep -f "signal-desktop\|electron.*Signal" >/dev/null 2>&1
            else
                ${openssh}/bin/ssh "$host" "${procps}/bin/pgrep -f 'signal-desktop\|electron.*Signal' >/dev/null 2>&1"
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
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$APP_PATH/" "$TARGET_IP:.config/Signal/"
                else
                    # Ensure target directory exists and transfer
                    ${openssh}/bin/ssh "$TARGET_IP" "mkdir -p ~/.config"
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats "$APP_PATH/" "$TARGET_IP:.config/Signal/"
                fi
                ;;
            receive)
                mkdir -p "$(dirname "$APP_PATH")"
                
                # Wait for Signal to be closed on both machines
                wait_for_signal_closure "$TARGET_IP"
                
                # Calculate remote directory size
                echo "Calculating remote Signal profile size..."
                REMOTE_SIZE=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sb ~/.config/Signal 2>/dev/null | ${coreutils}/bin/cut -f1 || echo 0")
                if [ "$REMOTE_SIZE" -gt 0 ]; then
                    REMOTE_SIZE_HUMAN=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sh ~/.config/Signal | ${coreutils}/bin/cut -f1")
                    echo "Remote Signal profile size: $REMOTE_SIZE_HUMAN ($REMOTE_SIZE bytes)"
                fi
                
                echo "Receiving Signal profile from $TARGET_IP..."
                ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats $DRY_RUN "$TARGET_IP:.config/Signal/" "$APP_PATH/"
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
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$APP_PATH/" "$TARGET_IP:.config/microsoft-edge/"
                else
                    # Ensure target directory exists and transfer
                    ${openssh}/bin/ssh "$TARGET_IP" "mkdir -p ~/.config"
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats "$APP_PATH/" "$TARGET_IP:.config/microsoft-edge/"
                fi
                ;;
            receive)
                mkdir -p "$(dirname "$APP_PATH")"
                
                # Wait for Edge to be closed on both machines
                wait_for_edge_closure "$TARGET_IP"
                
                # Calculate remote directory size
                echo "Calculating remote Edge profile size..."
                REMOTE_SIZE=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sb ~/.config/microsoft-edge 2>/dev/null | ${coreutils}/bin/cut -f1 || echo 0")
                if [ "$REMOTE_SIZE" -gt 0 ]; then
                    REMOTE_SIZE_HUMAN=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sh ~/.config/microsoft-edge | ${coreutils}/bin/cut -f1")
                    echo "Remote Edge profile size: $REMOTE_SIZE_HUMAN ($REMOTE_SIZE bytes)"
                fi
                
                echo "Receiving Edge profile from $TARGET_IP..."
                ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats $DRY_RUN "$TARGET_IP:.config/microsoft-edge/" "$APP_PATH/"
                ;;
        esac
        echo "Transfer completed!"
      '')
      
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
                        ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$ZETTEL_PATH/" "$TARGET_IP:zettelkasten/"
                    else
                        ${openssh}/bin/ssh "$TARGET_IP" "mkdir -p ~/zettelkasten"
                        ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats "$ZETTEL_PATH/" "$TARGET_IP:zettelkasten/"
                    fi
                fi
                
                # Transfer config directory  
                if [ -d "$CONFIG_PATH" ]; then
                    echo "Sending Zettelkasten config to $TARGET_IP..."
                    if [ -n "$DRY_RUN" ]; then
                        echo "DRY RUN: Would transfer config directory"
                        ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete $DRY_RUN "$CONFIG_PATH/" "$TARGET_IP:.config/zettelkasten/"
                    else
                        ${openssh}/bin/ssh "$TARGET_IP" "mkdir -p ~/.config/zettelkasten"
                        ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats "$CONFIG_PATH/" "$TARGET_IP:.config/zettelkasten/"
                    fi
                fi
                ;;
                
            receive)
                mkdir -p "$(dirname "$ZETTEL_PATH")" "$(dirname "$CONFIG_PATH")"
                
                # Wait for Obsidian to be closed on both machines
                wait_for_obsidian_closure "$TARGET_IP"
                
                # Calculate remote sizes
                echo "Checking remote Zettelkasten sizes..."
                REMOTE_ZETTEL_SIZE=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sb ~/zettelkasten 2>/dev/null | ${coreutils}/bin/cut -f1 || echo 0")
                REMOTE_CONFIG_SIZE=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sb ~/.config/zettelkasten 2>/dev/null | ${coreutils}/bin/cut -f1 || echo 0")
                
                if [ "$REMOTE_ZETTEL_SIZE" -gt 0 ]; then
                    REMOTE_ZETTEL_SIZE_HUMAN=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sh ~/zettelkasten | ${coreutils}/bin/cut -f1")
                    echo "Remote Zettelkasten notes size: $REMOTE_ZETTEL_SIZE_HUMAN ($REMOTE_ZETTEL_SIZE bytes)"
                    
                    echo "Receiving Zettelkasten notes from $TARGET_IP..."
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats $DRY_RUN "$TARGET_IP:zettelkasten/" "$ZETTEL_PATH/"
                fi
                
                if [ "$REMOTE_CONFIG_SIZE" -gt 0 ]; then
                    REMOTE_CONFIG_SIZE_HUMAN=$(${openssh}/bin/ssh "$TARGET_IP" "${coreutils}/bin/du -sh ~/.config/zettelkasten | ${coreutils}/bin/cut -f1")
                    echo "Remote Zettelkasten config size: $REMOTE_CONFIG_SIZE_HUMAN ($REMOTE_CONFIG_SIZE bytes)"
                    
                    echo "Receiving Zettelkasten config from $TARGET_IP..."
                    ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --delete --stats $DRY_RUN "$TARGET_IP:.config/zettelkasten/" "$CONFIG_PATH/"
                fi
                
                if [ "$REMOTE_ZETTEL_SIZE" -eq 0 ] && [ "$REMOTE_CONFIG_SIZE" -eq 0 ]; then
                    echo "No Zettelkasten data found on remote host $TARGET_IP"
                fi
                ;;
        esac
        echo "Zettelkasten transfer completed!"
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
    microsoft.enable = lib.mkDefault true;  # Azure Cloud Architect tools
    nextcloud-client = {
      enable = lib.mkDefault true;
      serverUrl = "***REMOVED***";
      symlinkUserDirs = lib.mkDefault true;  # OneDrive-style integration
    };
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
