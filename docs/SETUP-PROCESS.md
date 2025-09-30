# NixOS Setup Process

Streamlined process for setting up a new NixOS host with this flake configuration.

## Overview

1. Boot NixOS ISO
2. Run `install-zfs.sh` → Follow its output
3. Run `nixos-install`
4. Run `flake-init.sh` → Follow its output for deployment

## Step-by-Step Process

### 1. Boot to NixOS Installation ISO

- Use NixOS unstable ISO with graphical environment
- Ensure you have network connectivity
- Choose LTS kernel for maximum hardware compatibility

### 2. Copy Repository to Target

From your development machine, set the target IP and copy the repo:

```bash
# Set target IP (adjust to your machine)
set TARGET_IP 10.17.19.89

# Copy repository to target
scp -r ~/nixconf root@$TARGET_IP:/root/

# SSH to target
ssh root@$TARGET_IP
```

**Backup plan (no dev machine):** `git clone https://github.com/Bakan0/nixconf.git`

### 3. Partition and Configure Storage

Run the ZFS installation script:

```bash
cd ~/nixconf

# Run the ZFS installation script with your target drive
./docs/install-zfs.sh /dev/nvme0n1
```

This script will:
- Set up LUKS2 encryption with TPM2 auto-unlock (if available)
- Create optimized ZFS pool with proper tuning
- Configure EFI boot partition
- Generate ZFS-specific optimizations
- Create base NixOS configuration

### 4. Install Base System

```bash
nixos-install
```

### 5. Initialize and Deploy

```bash
cd ~/nixconf
./docs/flake-init.sh HOSTNAME
```

**The script outputs exact commands to run. Follow them step-by-step:**

1. Copy files and stage for commit
2. Unmount, export ZFS pool, reboot target, and clean up old SSH key
3. Deploy configuration via `nixos-rebuild --target-host --build-host`
4. Reboot to BIOS firmware, clear Secure Boot keys, then enroll custom keys
5. Re-enroll TPM2 (clearing Secure Boot keys wipes TPM)
6. Copy nixconf to user home and optimize hardware config
7. Copy updated configuration back and commit everything

Your system will boot into your fully configured NixOS environment with:
- ✅ ZFS with optimizations
- ✅ TPM2 auto-unlock (if supported)
- ✅ Complete Hyprland desktop environment
- ✅ All your applications and configurations

## Future Updates

Once your system is deployed, use the standard flake workflow:

```bash
# Update flake and rebuild
cd ~/nixconf
git pull
nh os switch . -- --show-trace

# Or for quick updates
nh os switch ~/nixconf/.
```

## What You Get

1. **No manual partitioning** - ZFS script handles everything
2. **Hardware detection preserved** - Uses actual `nixos-install` output
3. **Script-guided deployment** - Exact commands provided by flake-init
4. **TPM2 auto-unlock** - No password typing after setup (where supported)
5. **Optimized by default** - ZFS tuning, performance settings, secure boot
6. **Immediate usability** - Full desktop environment ready on first boot

This process eliminates the complexity of manual NixOS setup while preserving all the power and customization of your flake configuration.
