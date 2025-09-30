# NixOS Setup Process

Streamlined process for setting up a new NixOS host with this flake configuration.

## Overview

1. Boot NixOS ISO
2. Run `preflight-zfs-secure.sh` → Follow its output
3. Run `nixos-install`
4. Run `flake-init.sh` → Follow its output for deployment

## Prerequisites

**For Secure Boot (Optional):**
Before running preflight-zfs-secure.sh, boot target machine to firmware setup and clear Secure Boot keys to enter Setup Mode. The script will auto-detect Setup Mode and automatically create and enroll lanzaboote keys.

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

Run the preflight script:

```bash
cd ~/nixconf && ./docs/preflight-zfs-secure.sh
```

The script will show available drives and prompt you to select one.

This script will:
- Set up LUKS2 encryption with TPM2 auto-unlock (if available)
- Create optimized ZFS pool with proper tuning
- Configure EFI boot partition
- Generate ZFS-specific optimizations
- Create base NixOS configuration
- Auto-detect Secure Boot Setup Mode and enroll lanzaboote keys (if enabled)

### 4. Install Base System

```bash
nixos-install
```

### 5. Initialize and Deploy

```bash
cd ~/nixconf && ./docs/flake-init.sh HOSTNAME
```

**The script outputs exact commands to run. Follow them step-by-step:**

1. Copy files and stage for commit
2. Unmount, export ZFS pool, reboot target, and clean up old SSH key
3. Deploy configuration via `nixos-rebuild --target-host --build-host`
4. Enroll Secure Boot keys (if Setup Mode was enabled before installation)
5. Optimize hardware config on target
6. Copy updated configuration back and commit everything

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

## Future Enhancements / Projects

### Automation Improvements
- [ ] **Auto-detect ASUS/Apple hardware** in `hardware-config-insert` script
  - Currently only detects Intel/AMD/NVIDIA GPUs
  - Should detect motherboard manufacturer and add appropriate bundles
  - Apple T2 detection already exists in `hardware-analyze` but not in auto-insert

- [ ] **Fix TPM2 enrollment persistence** for Secure Boot systems
  - **KNOWN ISSUE**: TPM2 auto-unlock breaks after nixos-rebuild when Secure Boot is enabled
  - Currently: TPM2 enrolled during preflight → works initially → breaks after any system rebuild
  - Root cause: PCR measurements change when system configuration changes
  - **Workaround**: Manually re-enroll TPM2 after each rebuild that changes boot components
    ```bash
    systemd-cryptenroll --wipe-slot=tpm2 /dev/disk/by-id/DEVICE-part2
    systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-id/DEVICE-part2
    ```
  - Goal: Make TPM2 enrollment survive rebuilds OR document automatic re-enrollment in rebuild hooks

- [ ] **Streamline flake-init.sh output**
  - Reduce number of manual copy-paste steps
  - Consider interactive prompts or automated execution where safe

### Documentation
- [ ] **Add troubleshooting section** to SETUP-PROCESS.md
  - Common issues: NVMe device enumeration changes, duplicate UUIDs, TPM2 enrollment timing
  - Solutions for when builds fail during deployment
  - How to verify Secure Boot status and re-enroll if needed

- [ ] **Document the "why"** behind TPM2 PCR selection (0+2+7)
  - PCR 0: UEFI firmware and configuration
  - PCR 2: UEFI drivers and boot applications
  - PCR 7: Secure Boot state
  - Why these specific PCRs matter for auto-unlock security

### Hardware Support
- [ ] **Expand hardware-config-insert** to detect more hardware types
  - Framework laptops (already have bundle)
  - System76 machines
  - Other common gaming laptop vendors (MSI, Razer, etc.)

- [ ] **Add NVIDIA GPU support** to hardware detection scripts
  - Currently marked as "configure manually"
  - Auto-detect and suggest appropriate driver configuration

### Testing
- [ ] **Create test matrix** for installation workflow
  - Test on: Intel-only, AMD-only, Hybrid systems
  - Test with/without TPM2
  - Test with/without Secure Boot
  - Document which combinations are verified working
