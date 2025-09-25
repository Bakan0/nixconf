{ config, lib, pkgs, ... }:
with pkgs;
{
  home.packages = [
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

              # Automatic post-transfer setup
              echo "Performing automatic post-transfer setup on $TARGET_IP..."

              echo "1. Restarting libvirtd service..."
              ${openssh}/bin/ssh -A "$TARGET_IP" "sudo systemctl restart libvirtd" || echo "Warning: Failed to restart libvirtd"

              echo "2. Waiting for libvirtd to be ready..."
              sleep 3

              echo "3. Auto-defining VMs from transferred configurations..."
              VM_XMLS=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo find /etc/libvirt/qemu -name '*.xml' -maxdepth 1 2>/dev/null" || true)
              if [ -n "$VM_XMLS" ]; then
                  echo "$VM_XMLS" | while IFS= read -r xml_path; do
                      if [ -n "$xml_path" ]; then
                          vm_name=$(basename "$xml_path" .xml)
                          echo "   Defining VM: $vm_name"
                          ${openssh}/bin/ssh -A "$TARGET_IP" "sudo virsh define '$xml_path'" || echo "   Failed to define $vm_name"
                      fi
                  done
              else
                  echo "   No VM XML files found to define"
              fi

              echo "4. Auto-starting available networks..."
              NETWORKS=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo virsh net-list --all --name 2>/dev/null | grep -v '^$'" || true)
              if [ -n "$NETWORKS" ]; then
                  echo "$NETWORKS" | while IFS= read -r network; do
                      if [ -n "$network" ] && [ "$network" != "default" ]; then
                          echo "   Starting network: $network"
                          ${openssh}/bin/ssh -A "$TARGET_IP" "sudo virsh net-start '$network' 2>/dev/null || echo '   Network $network already active or failed to start'"
                      fi
                  done
              else
                  echo "   No additional networks found to start"
              fi

              echo "5. Verification - Final status:"
              echo "VMs:"
              ${openssh}/bin/ssh -A "$TARGET_IP" "sudo virsh list --all 2>/dev/null || echo 'Failed to list VMs'"
              echo "Networks:"
              ${openssh}/bin/ssh -A "$TARGET_IP" "sudo virsh net-list --all 2>/dev/null || echo 'Failed to list networks'"

              echo "Post-transfer setup completed!"
              ;;

          receive)
              mkdir -p "$(dirname "$USER_CONFIGS_PATH")"

              # Wait for VMs to be shut down
              wait_for_vm_shutdown "$TARGET_IP"

              echo "Checking remote libvirt data sizes..."

              # Check and receive VM images
              REMOTE_IMAGES_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo du -sb /var/lib/libvirt/images 2>/dev/null | cut -f1 || echo 0" | tr -d '\r')
              if [ "$REMOTE_IMAGES_SIZE" -gt 0 ]; then
                  REMOTE_IMAGES_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo du -sh /var/lib/libvirt/images | cut -f1" | tr -d '\r')
                  echo "Remote VM images size: $REMOTE_IMAGES_SIZE_HUMAN ($REMOTE_IMAGES_SIZE bytes)"

                  echo "Receiving VM images from $TARGET_IP..."
                  sudo mkdir -p "$VM_IMAGES_PATH"
                  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --rsync-path="sudo rsync" -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:/var/lib/libvirt/images/" "$VM_IMAGES_PATH/"
              fi

              # Check and receive VM configurations
              REMOTE_CONFIGS_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo du -sb /etc/libvirt/qemu 2>/dev/null | cut -f1 || echo 0" | tr -d '\r')
              if [ "$REMOTE_CONFIGS_SIZE" -gt 0 ]; then
                  REMOTE_CONFIGS_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo du -sh /etc/libvirt/qemu | cut -f1" | tr -d '\r')
                  echo "Remote VM configs size: $REMOTE_CONFIGS_SIZE_HUMAN ($REMOTE_CONFIGS_SIZE bytes)"

                  echo "Receiving VM configurations from $TARGET_IP..."
                  sudo mkdir -p "$VM_CONFIGS_PATH"
                  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --rsync-path="sudo rsync" -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:/etc/libvirt/qemu/" "$VM_CONFIGS_PATH/"
              fi

              # Check and receive network configurations
              REMOTE_NETWORK_SIZE=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo du -sb /etc/libvirt/qemu/networks 2>/dev/null | cut -f1 || echo 0" | tr -d '\r')
              if [ "$REMOTE_NETWORK_SIZE" -gt 0 ]; then
                  REMOTE_NETWORK_SIZE_HUMAN=$(${openssh}/bin/ssh -A "$TARGET_IP" "sudo du -sh /etc/libvirt/qemu/networks | cut -f1" | tr -d '\r')
                  echo "Remote network configs size: $REMOTE_NETWORK_SIZE_HUMAN ($REMOTE_NETWORK_SIZE bytes)"

                  echo "Receiving network configurations from $TARGET_IP..."
                  sudo mkdir -p "$NETWORK_CONFIGS_PATH"
                  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ${rsync}/bin/rsync -avz --compress-choice=zstd --compress-level=3 --progress --rsync-path="sudo rsync" -e "ssh -A" --delete --stats $DRY_RUN "$TARGET_IP:/etc/libvirt/qemu/networks/" "$NETWORK_CONFIGS_PATH/"
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

              # Automatic post-transfer setup (local)
              echo "Performing automatic post-transfer setup locally..."

              echo "1. Restarting libvirtd service..."
              sudo systemctl restart libvirtd

              echo "2. Waiting for libvirtd to be ready..."
              sleep 3

              echo "3. Auto-defining VMs from received configurations..."
              if [ -d "/etc/libvirt/qemu" ]; then
                  VM_XMLS=$(sudo find /etc/libvirt/qemu -name '*.xml' -maxdepth 1 2>/dev/null || true)
                  if [ -n "$VM_XMLS" ]; then
                      echo "$VM_XMLS" | while IFS= read -r xml_path; do
                          if [ -n "$xml_path" ]; then
                              vm_name=$(basename "$xml_path" .xml)
                              echo "   Defining VM: $vm_name"
                              sudo virsh define "$xml_path" || echo "   Failed to define $vm_name"
                          fi
                      done
                  else
                      echo "   No VM XML files found to define"
                  fi
              fi

              echo "4. Auto-starting available networks..."
              NETWORKS=$(sudo virsh net-list --all --name 2>/dev/null | grep -v '^$' || true)
              if [ -n "$NETWORKS" ]; then
                  echo "$NETWORKS" | while IFS= read -r network; do
                      if [ -n "$network" ] && [ "$network" != "default" ]; then
                          echo "   Starting network: $network"
                          sudo virsh net-start "$network" 2>/dev/null || echo "   Network $network already active or failed to start"
                      fi
                  done
              else
                  echo "   No additional networks found to start"
              fi

              echo "5. Verification - Final status:"
              echo "VMs:"
              sudo virsh list --all 2>/dev/null || echo "Failed to list VMs"
              echo "Networks:"
              sudo virsh net-list --all 2>/dev/null || echo "Failed to list networks"

              echo "Post-transfer setup completed!"
              ;;
      esac
      echo "Libvirt transfer completed!"
    '')
  ];
}