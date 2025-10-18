#!/usr/bin/env bash
# Complete ZFS NixOS Installation with TPM2 Auto-Unlock
# FIXED: Proper hardware config generation, no filesystem conflicts

set -euo pipefail

# Check if running from NixOS installer
if [[ ! -f /etc/NIXOS ]]; then
    echo "❌ This script must be run from NixOS installer ISO"
    exit 1
fi

# Variables that don't require tools
DRIVE="${1:-}"
if [[ -z "$DRIVE" ]]; then
    echo "💾 Available drives:"
    echo ""

    # Get list of drives excluding the USB stick
    mapfile -t DRIVES < <(lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk | awk '{print $1}')

    for i in "${!DRIVES[@]}"; do
        DNAME="${DRIVES[$i]}"
        INFO=$(lsblk -d -n -o SIZE,MODEL "/dev/$DNAME")
        printf "%d) /dev/%-8s %s\n" "$((i+1))" "$DNAME" "$INFO"
    done

    echo ""
    read -p "Select drive number (or enter full path like /dev/nvme0n1): " SELECTION

    if [[ -z "$SELECTION" ]]; then
        echo "❌ No drive specified"
        exit 1
    fi

    # Check if selection is a number
    if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
        INDEX=$((SELECTION - 1))
        if [[ $INDEX -ge 0 && $INDEX -lt ${#DRIVES[@]} ]]; then
            DRIVE="/dev/${DRIVES[$INDEX]}"
        else
            echo "❌ Invalid selection"
            exit 1
        fi
    else
        DRIVE="$SELECTION"
    fi
fi

# Find stable by-id path for the drive (or use direct path for VMs)
echo "🔍 Finding stable device identifier..."
DRIVE_BASENAME=$(basename "$DRIVE")
DRIVE_BY_ID=$(ls -l /dev/disk/by-id/ | grep "../../$DRIVE_BASENAME\$" | grep -v -- '-part' | awk '{print $9}' | head -1 || true)

if [[ -z "$DRIVE_BY_ID" ]]; then
    # No by-id path found - common for virtio disks without serial numbers
    echo "⚠️  No /dev/disk/by-id entry found for $DRIVE"

    # Check if this is a virtio disk (VM)
    if [[ "$DRIVE" =~ /dev/vd[a-z] ]]; then
        echo "✅ Detected virtio disk (VM) - using direct path: $DRIVE"
        DRIVE_BY_ID_PATH="$DRIVE"
    else
        echo "❌ Could not find stable by-id path for $DRIVE"
        echo "Available devices:"
        ls -l /dev/disk/by-id/
        exit 1
    fi
else
    DRIVE_BY_ID_PATH="/dev/disk/by-id/$DRIVE_BY_ID"
    echo "✅ Using stable identifier: $DRIVE_BY_ID_PATH"
fi

# Determine partition naming scheme (nvme uses p1, others use just 1)
if [[ "$DRIVE" =~ nvme ]]; then
    PART_PREFIX="${DRIVE}p"
else
    PART_PREFIX="${DRIVE}"
fi
echo ""

# Execute the ENTIRE installation within nix-shell environment
echo "📦 Installing all tools and running complete installation..."
exec nix-shell -p zfs parted cryptsetup util-linux e2fsprogs dosfstools dmidecode tpm2-tools systemd --run "
    set -euo pipefail
    echo '✅ All tools installed and available throughout installation'

    # Set LUKS device path - use proper partition naming
    # For VMs (direct paths like /dev/vda), use partition number directly
    # For by-id paths, use -part2 suffix
    if [[ '$DRIVE_BY_ID_PATH' =~ ^/dev/disk/by-id/ ]]; then
        LUKS_DEVICE='$DRIVE_BY_ID_PATH-part2'
    else
        LUKS_DEVICE='${PART_PREFIX}2'
    fi

    # Constants
    EFI_SIZE='3.5GiB'

    # Get actual installed RAM from memory sticks (NOW AVAILABLE)
    echo '🔍 Detecting installed memory sticks...'
    INSTALLED_RAM_GB=\$(dmidecode -t 17 | grep '^\s*Size:' | grep -v 'No Module' | awk '{sum += \$2} END {print sum}')

    if [[ -n \"\$INSTALLED_RAM_GB\" && \"\$INSTALLED_RAM_GB\" -gt 0 ]]; then
        TOTAL_RAM_GB=\$INSTALLED_RAM_GB
        TOTAL_RAM_BYTES=\$((TOTAL_RAM_GB * 1024 * 1024 * 1024))
        echo \"✅ Found memory sticks totaling: \${TOTAL_RAM_GB}GB\"
    else
        echo '⚠️  dmidecode parsing failed, using fallback'
        TOTAL_RAM_MB=\$(free -m | awk '/^Mem:/ {print \$2}')
        TOTAL_RAM_GB=\$((TOTAL_RAM_MB / 1024))
        if [[ \$((TOTAL_RAM_MB % 1024)) -ge 512 ]]; then
            TOTAL_RAM_GB=\$((TOTAL_RAM_GB + 1))
        fi
        TOTAL_RAM_BYTES=\$((TOTAL_RAM_GB * 1024 * 1024 * 1024))
        echo \"✅ Using fallback detection: \${TOTAL_RAM_GB}GB\"
    fi

    # Calculate ARC limit (25% of total RAM)
    ARC_SIZE=\$((TOTAL_RAM_BYTES / 4))

    echo \"🚀 Installing ZFS NixOS with TPM2 Auto-Unlock (impermanence-ready layout) on $DRIVE\"
    echo \"🧠 Total RAM: \${TOTAL_RAM_GB}GB\"
    echo \"📊 ARC Size: \$((ARC_SIZE / 1024 / 1024 / 1024))GB (25% of RAM)\"
    echo \"💾 EFI: \$EFI_SIZE\"
    echo \"🔐 TPM2: Automatic LUKS unlock (with password fallback)\"
    echo \"⚡ Optimizations: zstd compression, 25% ARC tuning, performance settings\"
    echo \"🔄 Impermanence-ready: Enable myNixOS.impermanence in config to wipe root on boot\"
    read -p 'Continue? (y/N): ' confirm

    if [[ \"\$confirm\" != 'y' ]]; then
        echo 'Installation cancelled.'
        exit 0
    fi

    # Enhanced cleanup of existing mounts and partitions
    echo '🧹 Performing thorough cleanup...'

    # Unmount specific mount points first
    echo '  Unmounting specific filesystems...'
    umount /mnt/boot 2>/dev/null || true
    umount /mnt/home 2>/dev/null || true
    umount /mnt/persist 2>/dev/null || true
    umount /mnt/nix 2>/dev/null || true
    umount /mnt 2>/dev/null || true

    # Unmount all mounts under /mnt (recursive)
    echo '  Unmounting all /mnt filesystems...'
    umount -R /mnt 2>/dev/null || true

    # Unmount any direct mounts of the drive partitions
    echo '  Unmounting drive partitions...'
    umount \"$DRIVE\"* 2>/dev/null || true

    # Export any ZFS pools
    echo '  Exporting ZFS pools...'
    zpool export rpool 2>/dev/null || true
    zpool export -a 2>/dev/null || true

    # Close any LUKS devices
    echo '  Closing LUKS devices...'
    cryptsetup luksClose luks-rpool 2>/dev/null || true

    # Find and close any other LUKS devices on this drive
    for luks_dev in \$(ls /dev/mapper/ 2>/dev/null | grep -v control); do
        if cryptsetup status \"\$luks_dev\" 2>/dev/null | grep -q \"$DRIVE\"; then
            echo \"  Closing LUKS device: \$luks_dev\"
            cryptsetup luksClose \"\$luks_dev\" 2>/dev/null || true
        fi
    done

    # Deactivate any LVM volumes
    echo '  Deactivating LVM...'
    vgchange -an 2>/dev/null || true

    # Stop any mdadm arrays
    echo '  Stopping mdadm arrays...'
    mdadm --stop --scan 2>/dev/null || true

    # Clear any device mapper entries
    echo '  Clearing device mapper...'
    dmsetup remove_all 2>/dev/null || true

    # Wait a moment for cleanup to complete
    sleep 3

    # Final check - show what's using the drive
    echo '  Final check...'
    lsblk \"$DRIVE\" || true

    echo '  Cleanup complete!'

    # Partition setup
    echo '💾 Creating optimal partition layout...'
    parted \"$DRIVE\" --script -- mklabel gpt
    parted \"$DRIVE\" --script -- mkpart ESP fat32 1MiB \"\$EFI_SIZE\"
    parted \"$DRIVE\" --script -- set 1 esp on
    parted \"$DRIVE\" --script -- mkpart primary \"\$EFI_SIZE\" 100%

    # Wait for kernel to recognize new partitions
    echo '⏳ Waiting for kernel to recognize partitions...'
    partprobe \"$DRIVE\"
    udevadm settle --timeout=10
    sleep 2

    # Format EFI partition
    echo '🔧 Formatting EFI partition...'
    mkfs.fat -F 32 -n EFI \"${PART_PREFIX}1\"

    # LUKS setup with optimal settings + TPM2 enrollment
    echo '🔐 Setting up LUKS2 encryption with TPM2 auto-unlock...'
    echo 'Enter LUKS password for this machine (you'\''ll rarely need to type this after TPM2 setup):'
    cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --key-size 512 --hash sha256 \"${PART_PREFIX}2\"
    cryptsetup luksOpen \"${PART_PREFIX}2\" luks-rpool

    # Check if TPM2 is available and enroll key
    echo '🔒 Checking TPM2 availability...'
    TPM2_ENROLLED=false
    if [[ -c /dev/tpmrm0 ]] || [[ -c /dev/tpm0 ]]; then
        echo '✅ TPM2 detected, enrolling LUKS key for automatic unlock...'
        if systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 \"${PART_PREFIX}2\"; then
            echo '🎉 TPM2 enrollment successful! System will auto-unlock on boot.'
            TPM2_ENROLLED=true
        else
            echo '⚠️  TPM2 enrollment failed, continuing with password-only unlock'
            TPM2_ENROLLED=false
        fi
    else
        echo '⚠️  No TPM2 device found, using password-only unlock'
        TPM2_ENROLLED=false
    fi

    # Generate unique hostid for ZFS
    HOSTID=\$(head -c 8 /etc/machine-id)

    # ZFS pool creation (tools are now available)
    echo '🏊 Creating optimized ZFS pool...'
    zpool create -f \\
        -o ashift=12 \\
        -o autotrim=on \\
        -o compatibility=openzfs-2.1-linux \\
        -O compression=zstd \\
        -O acltype=posixacl \\
        -O xattr=sa \\
        -O relatime=on \\
        -O normalization=formD \\
        -O dnodesize=auto \\
        -O sync=standard \\
        -O logbias=latency \\
        -O mountpoint=none \\
        -O canmount=off \\
        -R /mnt \\
        rpool /dev/mapper/luks-rpool

    # Create impermanence-ready dataset structure
    echo '📁 Creating ZFS datasets (impermanence-ready)...'

    # System datasets
    zfs create -o mountpoint=legacy -o canmount=noauto \\
        -o recordsize=128K -o compression=zstd \\
        -o sync=standard -o logbias=latency \\
        rpool/root
    zfs create -o mountpoint=legacy \\
        -o recordsize=128K -o compression=zstd \\
        -o sync=standard -o atime=off \\
        rpool/nix

    # Persistent data dataset (optimized for large files)
    zfs create -o mountpoint=legacy \\
        -o recordsize=1M -o compression=zstd \\
        -o sync=standard -o logbias=throughput \\
        rpool/persist

    # Mount filesystems in correct order
    echo '🔗 Mounting filesystems...'
    mount -t zfs rpool/root /mnt
    mkdir -p /mnt/nix
    mount -t zfs rpool/nix /mnt/nix
    mkdir -p /mnt/persist
    mount -t zfs rpool/persist /mnt/persist
    mkdir -p /mnt/boot
    mount \"${PART_PREFIX}1\" /mnt/boot

    # Create /persist/home and bind mount it to /home
    mkdir -p /mnt/persist/home
    mkdir -p /mnt/home
    mount --bind /mnt/persist/home /mnt/home

    # Create blank snapshot for future impermanence use
    zfs snapshot rpool/root@blank

    # Generate hardware configuration FIRST (detects ZFS automatically)
    echo '⚙️  Generating NixOS hardware configuration...'
    nixos-generate-config --root /mnt

    # Create ZFS optimizations config (WITHOUT filesystem definitions - hardware config handles those)
    echo '📝 Creating ZFS optimizations configuration...'
    cat > /mnt/etc/nixos/zfs-optimizations.nix << 'NIXEOF'
{ config, lib, pkgs, ... }:

{
  # ZFS kernel module optimization with 25% ARC
  boot.extraModprobeConfig = ''
    # ARC settings: 25% of system RAM (TOTAL_RAM_GB_PLACEHOLDER GB detected)
    options zfs zfs_arc_max=ARC_SIZE_PLACEHOLDER
    options zfs zfs_arc_min=ARC_SIZE_PLACEHOLDER
    options zfs zfs_prefetch_disable=0
    options zfs zfs_txg_timeout=5
    options zfs zfs_vdev_scrub_max_active=3
    options zfs zfs_vdev_sync_read_max_active=20
    options zfs zfs_vdev_sync_write_max_active=20
    options zfs zfs_dirty_data_max_percent=25
    options zfs zfs_vdev_async_read_max_active=3
    options zfs zfs_vdev_async_write_max_active=10
  '';

  # System tuning for ZFS performance
  boot.kernel.sysctl = {
    # Memory management for ZFS
    \"vm.swappiness\" = 1;
    \"vm.dirty_background_ratio\" = 5;
    \"vm.dirty_ratio\" = 10;
    \"vm.dirty_expire_centisecs\" = 6000;
    \"vm.dirty_writeback_centisecs\" = 500;
    \"vm.vfs_cache_pressure\" = 50;

    # Network optimizations
    \"net.core.rmem_default\" = 262144;
    \"net.core.rmem_max\" = 16777216;
    \"net.core.wmem_default\" = 262144;
    \"net.core.wmem_max\" = 16777216;
    \"net.core.netdev_max_backlog\" = 5000;

    # File system optimizations
    \"fs.file-max\" = 2097152;
    \"fs.inotify.max_user_watches\" = 524288;
  };

  # TPM2 support for LUKS auto-unlock
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Enable systemd in initrd for TPM2 unlock
  boot.initrd.systemd.enable = true;

  # LUKS configuration with TPM2 support
  boot.initrd.luks.devices.\"luks-rpool\" = {
    device = \"DRIVE_PLACEHOLDER2\";
    TPM2_CONFIG_PLACEHOLDER
  };

  # ZFS services with optimal settings
  services.zfs.autoScrub = {
    enable = true;
    interval = \"monthly\";
    pools = [ \"rpool\" ];
  };

  services.zfs.autoSnapshot = {
    enable = true;
    flags = \"-k -p --utc\";
    frequent = 8;   # 15-minute snapshots, keep 8 (2 hours)
    hourly = 48;    # Keep 48 hourly (2 days)
    daily = 14;     # Keep 14 daily (2 weeks)
    weekly = 8;     # Keep 8 weekly (2 months)
    monthly = 12;   # Keep 12 monthly (1 year)
  };

  # ZFS trim service for SSD optimization
  services.zfs.trim = {
    enable = true;
    interval = \"weekly\";
  };

  # Enable ZFS auto-import
  boot.zfs.devNodes = \"/dev/disk/by-id\";
  boot.zfs.forceImportRoot = false;
  boot.zfs.forceImportAll = false;

  # Networking with unique hostId
  networking.hostId = lib.mkDefault \"HOSTID_PLACEHOLDER\";

  # No swap (as requested)
  swapDevices = [ ];

  # Mark /persist as needed for boot (required for impermanence)
  fileSystems.\"/persist\".neededForBoot = true;

  # Bind mount /home to /persist/home (always, regardless of impermanence)
  fileSystems.\"/home\" = {
    device = \"/persist/home\";
    options = [ \"bind\" ];
  };

  # Enable periodic filesystem checks
  systemd.services.zfs-mount.enable = true;

  # ZFS-specific systemd services
  systemd.services.zfs-import-rpool = {
    description = \"Import ZFS pool rpool\";
    wantedBy = [ \"zfs-import.target\" ];
    after = [ \"systemd-udev-settle.service\" ];
    serviceConfig = {
      Type = \"oneshot\";
      RemainAfterExit = true;
    };
    script = ''
      \${pkgs.zfs}/bin/zpool import -d /dev/disk/by-id -aN
    '';
  };

  # Performance monitoring and ZFS tools
  environment.systemPackages = with pkgs; [
    zfs
    smartmontools
    iotop
    htop
    btop
    nvme-cli
    lm_sensors
    pciutils
    usbutils
    tpm2-tools
  ];

  # Enable fstrim for all SSD filesystems
  services.fstrim = {
    enable = true;
    interval = \"weekly\";
  };
}
NIXEOF

    # Replace placeholders with actual values using sed
    sed -i \"s/HOSTID_PLACEHOLDER/\$HOSTID/g\" /mnt/etc/nixos/zfs-optimizations.nix
    sed -i \"s|DRIVE_PLACEHOLDER2|\$LUKS_DEVICE|g\" /mnt/etc/nixos/zfs-optimizations.nix
    sed -i \"s/ARC_SIZE_PLACEHOLDER/\$ARC_SIZE/g\" /mnt/etc/nixos/zfs-optimizations.nix
    sed -i \"s/TOTAL_RAM_GB_PLACEHOLDER/\$TOTAL_RAM_GB/g\" /mnt/etc/nixos/zfs-optimizations.nix

    # Configure TPM2 settings based on enrollment success
    if [[ \"\$TPM2_ENROLLED\" == \"true\" ]]; then
        TPM2_CONFIG='crypttabExtraOpts = [ \"tpm2-device=auto\" \"tpm2-pcrs=0+2+7\" ];'
        echo '🔐 Configured TPM2 auto-unlock'
    else
        TPM2_CONFIG='# TPM2 enrollment failed - password-only unlock'
        echo '🔑 Configured password-only unlock'
    fi

    sed -i \"s/TPM2_CONFIG_PLACEHOLDER/\$TPM2_CONFIG/g\" /mnt/etc/nixos/zfs-optimizations.nix

    # Update main configuration to include ZFS optimizations
    echo '🔧 Updating main NixOS configuration...'
    sed -i '/hardware-configuration.nix/a\\    ./zfs-optimizations.nix' /mnt/etc/nixos/configuration.nix

    # Add basic system configuration if not present
    if ! grep -q 'networking.networkmanager.enable' /mnt/etc/nixos/configuration.nix; then
        cat >> /mnt/etc/nixos/configuration.nix << 'SYSEOF'

  # Basic system configuration
  networking.networkmanager.enable = true;
  time.timeZone = lib.mkDefault \"America/Chicago\";  # Adjust as needed


  # User configuration (adjust as needed)
  users.users.root.hashedPassword = \"!\";  # Disable root login

  # Enable flakes and new nix command
  nix.settings.experimental-features = [ \"nix-command\" \"flakes\" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # system.stateVersion will be automatically set by nixos-install
SYSEOF
    fi

    # Set proper permissions
    chmod 644 /mnt/etc/nixos/zfs-optimizations.nix
    chmod 644 /mnt/etc/nixos/configuration.nix

    # Display pool status
    echo ''
    echo '📊 ZFS Pool Status:'
    zpool status rpool
    echo ''
    echo '📁 ZFS Datasets:'
    zfs list
    echo ''
    echo '💾 Filesystem Mounts:'
    df -h /mnt /mnt/nix /mnt/persist /mnt/home /mnt/boot

    echo ''
    echo '✅ Installation preparation complete!'
    echo ''
    echo '🚀 What was configured:'
    echo \"   • Impermanence-ready dataset layout (rpool/root, rpool/nix, rpool/persist)\"
    echo \"   • /home → /persist/home (always persistent, regardless of impermanence)\"
    echo \"   • Blank root snapshot created for future impermanence use\"
    echo \"   • zstd compression for better ratios\"
    echo \"   • 25% ARC limit: \$((ARC_SIZE / 1024 / 1024 / 1024))GB (25% of \${TOTAL_RAM_GB}GB RAM)\"
    echo \"   • Optimized record sizes (128K root/nix, 1M persist for large files)\"
    echo \"   • Performance-tuned kernel parameters\"
    echo \"   • Automated snapshots and scrubbing\"
    echo \"   • SSD-optimized settings with TRIM\"
    echo \"   • systemd-boot (no GRUB complexity)\"
    if [[ \"\$TPM2_ENROLLED\" == \"true\" ]]; then
        echo \"   • TPM2 auto-unlock (password fallback available)\"
    else
        echo \"   • Password-only unlock (TPM2 not available)\"
    fi
    echo ''
    echo \"💡 Hardware config handles filesystem detection automatically\"
    echo \"💡 ZFS optimizations in separate config - no conflicts!\"
    echo \"💡 To enable impermanence: set myNixOS.impermanence.enable = true\"
    echo ''

    # Check if Secure Boot is in Setup Mode and enroll keys at the END
    SETUP_MODE=\$(cat /sys/firmware/efi/efivars/SetupMode-* 2>/dev/null | od -An -t u1 | awk '{print \$NF}')
    if [[ \"\$SETUP_MODE\" == \"1\" ]]; then
        echo \"🔐 Secure Boot is in Setup Mode - setting up lanzaboote keys...\"
        SBCTL=\$(nix-build '<nixpkgs>' -A sbctl --no-out-link 2>/dev/null)/bin/sbctl
        if [[ -x \"\$SBCTL\" ]]; then
            \$SBCTL create-keys
            mkdir -p /mnt/persist/system/var/lib/sbctl
            cp -r /var/lib/sbctl/* /mnt/persist/system/var/lib/sbctl/
            if \$SBCTL enroll-keys --microsoft; then
                echo \"✅ Secure Boot keys created, copied, and enrolled!\"
                echo \"   • Keys stored in /mnt/persist/system/var/lib/sbctl/\"
                echo \"   • Keys enrolled to firmware (with Microsoft certs)\"
            else
                echo \"⚠️  Key enrollment failed - keys created and copied, but not enrolled to firmware\"
                echo \"   • Keys stored in /mnt/persist/system/var/lib/sbctl/\"
                echo \"   • You can enroll manually later with: sbctl enroll-keys --microsoft\"
            fi
        else
            echo \"⚠️  Could not build sbctl - skipping key enrollment\"
        fi
        echo ''
    fi

    echo '🎯 Next step:'
    echo '   nixos-install'
"

