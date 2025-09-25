{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myHomeManager.microsoft;
in {
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # Microsoft Edge browser for GCCH environments
      microsoft-edge

      # Azure CLI with extensions for cloud architecture work
      (azure-cli.overrideAttrs (oldAttrs: {
        doInstallCheck = false;  # Skip tests for faster builds
      }))
      azure-cli-extensions.azure-firewall
      # azure-cli-extensions.costmanagement
      azure-cli-extensions.fzf
      # azure-cli-extensions.ip-group
      # azure-cli-extensions.mdp
      # azure-cli-extensions.multicloud-connector
      # azure-cli-extensions.subscription
      # azure-cli-extensions.virtual-network-manager
      # azure-cli-extensions.virtual-wan

      # PowerShell for Azure automation
      powershell

      # Microsoft workspace launcher
      (writeShellScriptBin "microsoft" ''
        set -euo pipefail

        # Detect if running on Wayland and set appropriate flags for screen sharing
        EDGE_FLAGS=""
        if [[ "''${XDG_SESSION_TYPE:-}" == "wayland" ]] || [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            echo "🖥️  Wayland session detected - enabling screen sharing support"
            EDGE_FLAGS="--enable-features=WebRTCPipeWireCapturer,WaylandWindowDecorations --ozone-platform-hint=auto --enable-webrtc-pipewire-capturer"
        fi

        # Discover existing Edge profiles and their names
        EDGE_CONFIG_DIR="$HOME/.config/microsoft-edge"
        declare -A PROFILE_NAMES
        WORK_PROFILE=""
        ADMIN_PROFILE=""
        WORK_PROFILE_FLAG=""
        ADMIN_PROFILE_FLAG=""

        if [[ -f "$EDGE_CONFIG_DIR/Local State" ]]; then
            # Parse Local State to get profile names
            while IFS=: read -r profile_dir profile_name; do
                profile_dir=$(echo "$profile_dir" | xargs)
                profile_name=$(echo "$profile_name" | xargs)

                if [[ -d "$EDGE_CONFIG_DIR/$profile_dir" ]]; then
                    PROFILE_NAMES["$profile_dir"]="$profile_name"

                    # Intelligently assign profiles based on name patterns
                    if [[ "$profile_name" == *"User"* ]] || [[ "$profile_name" == *"user"* ]]; then
                        WORK_PROFILE="$profile_dir"
                        WORK_PROFILE_FLAG="--profile-directory=\"$profile_dir\""
                        echo "  Found work profile: $profile_name ($profile_dir)"
                    elif [[ "$profile_name" == *"Admin"* ]] || [[ "$profile_name" == *"admin"* ]]; then
                        ADMIN_PROFILE="$profile_dir"
                        ADMIN_PROFILE_FLAG="--profile-directory=\"$profile_dir\""
                        echo "  Found admin profile: $profile_name ($profile_dir)"
                    fi
                fi
            done < <(jq -r '.profile.info_cache | to_entries[] | "\(.key): \(.value.name)"' "$EDGE_CONFIG_DIR/Local State" 2>/dev/null || true)
        fi

        # Fallback: if no User/Admin patterns found, use Default for work
        if [[ -z "$WORK_PROFILE" ]] && [[ -d "$EDGE_CONFIG_DIR/Default" ]]; then
            WORK_PROFILE="Default"
            WORK_PROFILE_FLAG="--profile-directory=\"Default\""
            PROFILE_NAMES["Default"]="Default"
            echo "  Using Default profile for work"
        fi

        # Fallback: if no admin profile found, try Profile 1
        if [[ -z "$ADMIN_PROFILE" ]]; then
            for profile_num in 1 2 3; do
                if [[ -d "$EDGE_CONFIG_DIR/Profile $profile_num" ]]; then
                    if [[ "$WORK_PROFILE" != "Profile $profile_num" ]]; then
                        ADMIN_PROFILE="Profile $profile_num"
                        ADMIN_PROFILE_FLAG="--profile-directory=\"Profile $profile_num\""
                        [[ -z "''${PROFILE_NAMES["Profile $profile_num"]}" ]] && PROFILE_NAMES["Profile $profile_num"]="Profile $profile_num"
                        echo "  Using Profile $profile_num for admin"
                        break
                    fi
                fi
            done
        fi

        show_help() {
            echo "Usage: microsoft [--help] [--work] [--admin] [--all] [--list-profiles]"
            echo "Launch Microsoft applications for productivity workflows"
            echo ""
            echo "Options:"
            echo "  --work           Launch work profile (Teams & Outlook PWAs)"
            echo "  --admin          Launch admin profile browser"
            echo "  --all            Launch everything (work PWAs + admin browser)"
            echo "  --list-profiles  List available Edge profiles"
            echo "  --help           Show this help message"
            echo ""
            echo "Default: Launches work profile if no options specified"
            echo ""
            echo "Profile Detection:"
            if [[ -n "$WORK_PROFILE" ]]; then
                echo "  Work Profile: ''${PROFILE_NAMES[$WORK_PROFILE]} ($WORK_PROFILE)"
            else
                echo "  Work Profile: None configured"
            fi
            if [[ -n "$ADMIN_PROFILE" ]]; then
                echo "  Admin Profile: ''${PROFILE_NAMES[$ADMIN_PROFILE]} ($ADMIN_PROFILE)"
            else
                echo "  Admin Profile: None configured"
            fi
        }

        list_profiles() {
            echo "🔍 Edge Profiles Found:"
            if [[ ''${#PROFILE_NAMES[@]} -eq 0 ]]; then
                echo "   No profiles found in $EDGE_CONFIG_DIR"
                echo "   Edge will create one on first launch"
            else
                for profile_dir in "''${!PROFILE_NAMES[@]}"; do
                    profile_name="''${PROFILE_NAMES[$profile_dir]}"
                    if [[ "$profile_dir" == "$WORK_PROFILE" ]]; then
                        echo "   • $profile_name ($profile_dir) - WORK PROFILE"
                    elif [[ "$profile_dir" == "$ADMIN_PROFILE" ]]; then
                        echo "   • $profile_name ($profile_dir) - ADMIN PROFILE"
                    else
                        echo "   • $profile_name ($profile_dir)"
                    fi
                done
            fi
        }

        launch_work_profile() {
            echo "🚀 Starting Microsoft work environment..."

            if [[ -z "$WORK_PROFILE" ]]; then
                echo "⚠️  No work profile detected. Edge will use default behavior."
            fi

            # Launch Teams PWA with work profile
            echo "  Starting Teams PWA..."
            eval "microsoft-edge --app=https://gov.teams.microsoft.us/v2 $WORK_PROFILE_FLAG $EDGE_FLAGS &"

            # Launch Outlook PWA with work profile
            echo "  Starting Outlook PWA..."
            eval "microsoft-edge --app=https://outlook.office365.us/ $WORK_PROFILE_FLAG $EDGE_FLAGS &"

            echo "✅ Microsoft work environment started!"
            echo "   - Teams PWA"
            echo "   - Outlook PWA"
            if [[ -n "$WORK_PROFILE" ]]; then
                echo "   - Using profile: ''${PROFILE_NAMES[$WORK_PROFILE]}"
            fi
        }

        launch_admin_profile() {
            echo "🛡️  Starting Microsoft admin environment..."

            if [[ -z "$ADMIN_PROFILE" ]]; then
                echo "⚠️  No admin profile detected. Edge will use default behavior."
            fi

            # Launch Microsoft Edge with admin profile
            if [[ -n "$ADMIN_PROFILE" ]]; then
                echo "  Starting Edge with profile: ''${PROFILE_NAMES[$ADMIN_PROFILE]}"
            else
                echo "  Starting Edge (default behavior)..."
            fi
            eval "microsoft-edge $ADMIN_PROFILE_FLAG $EDGE_FLAGS &"

            echo "✅ Microsoft admin environment started!"
            if [[ -n "$ADMIN_PROFILE" ]]; then
                echo "   - Edge profile: ''${PROFILE_NAMES[$ADMIN_PROFILE]}"
            fi
        }

        launch_all() {
            echo "🚀 Starting complete Microsoft environment..."

            if [[ -z "$WORK_PROFILE" ]]; then
                echo "⚠️  No work profile detected for PWAs."
            fi
            if [[ -z "$ADMIN_PROFILE" ]]; then
                echo "⚠️  No admin profile detected for browser."
            fi

            # Launch Teams PWA with work profile
            echo "  Starting Teams PWA..."
            eval "microsoft-edge --app=https://gov.teams.microsoft.us/v2 $WORK_PROFILE_FLAG $EDGE_FLAGS &"

            # Launch Outlook PWA with work profile
            echo "  Starting Outlook PWA..."
            eval "microsoft-edge --app=https://outlook.office365.us/ $WORK_PROFILE_FLAG $EDGE_FLAGS &"

            # Wait a moment for PWAs to start
            sleep 2

            # Launch Microsoft Edge with admin profile
            if [[ -n "$ADMIN_PROFILE" ]]; then
                echo "  Starting Edge with profile: ''${PROFILE_NAMES[$ADMIN_PROFILE]}"
            else
                echo "  Starting Edge (default behavior)..."
            fi
            eval "microsoft-edge $ADMIN_PROFILE_FLAG $EDGE_FLAGS &"

            echo "✅ Complete Microsoft environment started!"
            echo "   - Teams PWA"
            echo "   - Outlook PWA"
            if [[ -n "$WORK_PROFILE" ]]; then
                echo "   - Work profile: ''${PROFILE_NAMES[$WORK_PROFILE]}"
            fi
            if [[ -n "$ADMIN_PROFILE" ]]; then
                echo "   - Admin profile: ''${PROFILE_NAMES[$ADMIN_PROFILE]}"
            fi
        }

        # Parse arguments
        ACTION="work"  # Default action

        while [[ $# -gt 0 ]]; do
            case $1 in
                --work) ACTION="work"; shift ;;
                --admin) ACTION="admin"; shift ;;
                --all) ACTION="all"; shift ;;
                --list-profiles) ACTION="list"; shift ;;
                --help) show_help; exit 0 ;;
                *) echo "Unknown option: $1"; show_help; exit 1 ;;
            esac
        done

        case $ACTION in
            work) launch_work_profile ;;
            admin) launch_admin_profile ;;
            all) launch_all ;;
            list) list_profiles ;;
        esac
      '')
    ];
  };
}