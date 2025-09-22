{ config, lib, pkgs, inputs, utils, ... }:
with lib;
let
  cfg = config.myNixOS.apple;
in {
  options.myNixOS.apple.tpmUnlock = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable TPM-based LUKS unlock";
    };

    luksDevice = mkOption {
      type = types.str;
      default = "";
      description = "LUKS device to unlock (e.g. /dev/nvme0n1p2 or UUID)";
    };

    luksName = mkOption {
      type = types.str;
      default = "luks-rpool";
      description = "Name for the unlocked LUKS device";
    };

    tpmHandle = mkOption {
      type = types.str;
      default = "0x81000000";
      description = "TPM persistent handle where sealed key is stored";
    };
  };

  config = mkIf (cfg.enable && cfg.modelOverrides == "T2") {
    # NOTE: For T2 Macs, also add to your host's configuration.nix:
    # imports = [ inputs.nixos-hardware.nixosModules.apple-t2 ];

    # Early boot modules for T2 devices (Apple keyboard/trackpad support in LUKS)
    boot.initrd.kernelModules = [
      "apple-bce"         # Apple BCE driver for T2 devices
      "snd"               # Sound support for T2
      "snd_pcm"           # PCM sound support for T2
    ] ++ lib.optionals cfg.tpmUnlock.enable [
      "tpm_tis"
      "tpm_tis_core"
      "vfat"
      "nls_cp437"
      "nls_iso8859_1"
    ];

    boot.initrd.availableKernelModules = lib.optionals cfg.tpmUnlock.enable [
      "tpm_tis"
      "tpm_tis_core"
      "vfat"
      "nls_cp437"
      "nls_iso8859_1"
    ];

    # TPM support for T2 chip (using software TPM since T2 SEP isn't accessible)
    boot.kernelModules = [
      "tpm_tis"           # TPM TIS driver
      "tpm_tis_core"      # TPM TIS core
    ];

    # T2 Mac specific kernel parameters - these come AFTER nixos-hardware params
    boot.kernelParams = lib.mkAfter [
      "intel_iommu=on"    # Override any "off" setting with "on"
      "iommu=pt"          # Override any "off" setting with passthrough
      "pci=noaer"         # Disable PCIe Advanced Error Reporting
    ];

    # Software TPM for T2 Macs (since T2's Secure Enclave isn't exposed to Linux)
    # swtpm hits memory limits constantly (0x902 errors) but DOES work - just barely
    # The sealed LUKS key lives at a persistent TPM handle (configured per-host)
    systemd.services.swtpm = {
      description = "Software TPM Emulator for T2 Mac";
      wantedBy = [ "multi-user.target" ];
      before = [ "systemd-cryptsetup@luks\\x2drpool.service" ];

      serviceConfig = {
        Type = "simple";
        # Use /boot for persistent TPM state (accessible in initrd)
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /boot/swtpm-state";
        ExecStart = ''
          ${pkgs.swtpm}/bin/swtpm socket \
            --tpmstate dir=/boot/swtpm-state \
            --tpm2 \
            --server type=tcp,port=2321,disconnect \
            --ctrl type=tcp,port=2322 \
            --flags not-need-init
        '';
        Restart = "always";
      };
    };

    # Boot-time TPM unlock for LUKS using systemd initrd
    # Manual setup required first: Use 'setup-tpm-luks-unlock' command after configuration
    boot.initrd.systemd = mkIf cfg.tpmUnlock.enable {
      enable = true;

      # Include required packages
      initrdBin = with pkgs; [
        swtpm
        tpm2-tools
        cryptsetup
        coreutils  # For timeout command
      ];

      # Mount /boot in initrd so we can access TPM state
      mounts = [{
        what = "/dev/disk/by-label/EFI";
        where = "/boot";
        type = "vfat";
      }];

      # swtpm service in initrd - uses /boot for persistent state
      services.swtpm-initrd = {
        description = "Software TPM for initrd";
        wantedBy = [ "sysinit.target" ];
        after = [ "boot.mount" ];  # Wait for /boot to be mounted
        requires = [ "boot.mount" ];
        before = [ "cryptsetup-pre.target" "systemd-cryptsetup@${utils.escapeSystemdPath cfg.tpmUnlock.luksName}.service" ];

        serviceConfig = {
          Type = "forking";
          # /boot is mounted in initrd, use it for TPM state
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /boot/swtpm-state";
          ExecStart = "${pkgs.swtpm}/bin/swtpm socket --tpmstate dir=/boot/swtpm-state --tpm2 --server type=tcp,port=2321,disconnect --ctrl type=tcp,port=2322 --daemon --flags not-need-init";
        };
      };

      # TPM unlock service - runs early in boot
      services.tpm-unlock = {
        description = "TPM LUKS Unlock";
        after = [ "swtpm-initrd.service" "boot.mount" ];
        requires = [ "swtpm-initrd.service" "boot.mount" ];
        before = [ "systemd-cryptsetup@${utils.escapeSystemdPath cfg.tpmUnlock.luksName}.service" ];
        requiredBy = [ "systemd-cryptsetup@${utils.escapeSystemdPath cfg.tpmUnlock.luksName}.service" ];
        wantedBy = [ "cryptsetup.target" ];

        script = ''
          # Use IP address instead of localhost in early boot
          export TPM2TOOLS_TCTI="swtpm:host=127.0.0.1,port=2321"

          # Wait for swtpm to be ready
          echo "Waiting for swtpm to be ready..."
          for i in {1..10}; do
            if ${pkgs.tpm2-tools}/bin/tpm2_startup -c 2>/dev/null; then
              echo "swtpm is ready"
              break
            fi
            echo "Waiting for swtpm... attempt $i/10"
            sleep 0.5
          done

          # Wait for the LUKS device to be available
          LUKS_DEVICE="${cfg.tpmUnlock.luksDevice}"
          echo "Waiting for LUKS device: $LUKS_DEVICE"
          for i in {1..20}; do
            if [ -e "$LUKS_DEVICE" ]; then
              echo "LUKS device found"
              break
            fi
            echo "Waiting for device... attempt $i/20"
            sleep 0.5
          done

          if [ ! -e "$LUKS_DEVICE" ]; then
            echo "ERROR: LUKS device $LUKS_DEVICE not found!"
            exit 0  # Exit success so systemd-cryptsetup can prompt for password
          fi

          echo "Attempting TPM unlock from handle ${cfg.tpmUnlock.tpmHandle}..."
          if ${pkgs.tpm2-tools}/bin/tpm2_unseal -c ${cfg.tpmUnlock.tpmHandle} 2>&1 | \
             ${pkgs.cryptsetup}/bin/cryptsetup open "$LUKS_DEVICE" ${cfg.tpmUnlock.luksName} --key-file=- 2>&1; then
            echo "TPM unlock successful!"
            # Device is now unlocked, systemd-cryptsetup will see it's already open
            exit 0
          else
            echo "TPM unlock failed, falling back to password prompt"
            exit 0  # Exit success so systemd-cryptsetup can prompt for password
          fi
        '';

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = false;
          StandardInput = "null";
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
      };
    };

    # Enable TPM2 access tools
    security.tpm2 = {
      enable = true;
      tctiEnvironment.enable = true;
      pkcs11.enable = true;
    };

    # T2 WiFi firmware - use existing firmware from linux-firmware
    hardware.firmware = [
      (pkgs.runCommand "apple-t2-wifi-firmware" {} ''
        mkdir -p $out/lib/firmware/brcm

        # First copy all the base firmware files from linux-firmware
        cp -v ${pkgs.linux-firmware}/lib/firmware/brcm/brcmfmac4364b3-pcie* $out/lib/firmware/brcm/ 2>/dev/null || true

        # Now create the specific symlinks the T2 driver looks for
        cd $out/lib/firmware/brcm

        # Check what files we actually have
        ls -la brcmfmac4364b3-pcie* || true

        # Create symlinks to whichever base file exists
        if [ -f brcmfmac4364b3-pcie.bin ]; then
          echo "Creating symlinks to brcmfmac4364b3-pcie.bin"
          ln -sf brcmfmac4364b3-pcie.bin brcmfmac4364b3-pcie.apple,bali.bin
          ln -sf brcmfmac4364b3-pcie.bin brcmfmac4364b3-pcie.apple,bali-HRPN.bin
          ln -sf brcmfmac4364b3-pcie.bin brcmfmac4364b3-pcie.apple,bali-HRPN-u.bin
          ln -sf brcmfmac4364b3-pcie.bin brcmfmac4364b3-pcie.apple,bali-HRPN-u-7.7.bin
          ln -sf brcmfmac4364b3-pcie.bin brcmfmac4364b3-pcie.apple,bali-HRPN-u-7.7-X0.bin
          ln -sf brcmfmac4364b3-pcie.bin brcmfmac4364b3-pcie.apple,bali-X0.bin
        elif [ -f brcmfmac4364b3-pcie.txt ]; then
          echo "Warning: Only found txt file, not bin file"
        else
          echo "Warning: No brcmfmac4364b3-pcie files found in linux-firmware"
        fi
      '')
    ];

    # TouchBar support for MacBook Pro with Touch Bar (T2 models)
    hardware.apple.touchBar = {
      enable = true;
      settings = {
        MediaLayerDefault = true;      # Show media controls by default
        ShowButtonOutlines = false;    # Cleaner look without button outlines
        EnablePixelShift = true;       # Prevent OLED burn-in
      };
    };

    environment.systemPackages = with pkgs; [
      tiny-dfr       # TouchBar daemon for T2 MacBook Pro models
      swtpm          # Software TPM emulator
      tpm2-abrmd     # TPM2 Access Broker & Resource Manager
      tpm2-tools     # TPM 2.0 tools for working with software TPM
      tpm2-tss       # TPM Software Stack
      clevis         # Automated decryption framework
      jose           # JOSE tools for clevis

      # Script to set up TPM unlock (fights through swtpm memory errors)
      (pkgs.writeShellScriptBin "apple-t2-tpm-setup" ''
        #!${pkgs.bash}/bin/bash
        set -e

        echo "=== TPM LUKS Unlock Setup Script ==="
        echo "This will fight through swtpm's memory errors to seal a LUKS key"
        echo ""

        # Get the LUKS device
        LUKS_DEVICE="${cfg.tpmUnlock.luksDevice}"
        TPM_HANDLE="${cfg.tpmUnlock.tpmHandle}"

        if [ -z "$LUKS_DEVICE" ]; then
          echo "Error: Configure tpmUnlock.luksDevice in your host configuration first"
          exit 1
        fi

        echo "LUKS Device: $LUKS_DEVICE"
        echo "TPM Handle: $TPM_HANDLE"
        echo ""
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          exit 0
        fi

        # Set up TPM connection
        export TPM2TOOLS_TCTI="swtpm:host=localhost,port=2321"

        # Ensure swtpm is running
        sudo systemctl restart swtpm
        sleep 2

        # Initialize TPM
        echo "Initializing TPM..."
        tpm2_startup -c || true

        # Clear ANY existing handles that might interfere
        echo "Clearing any existing TPM handles..."
        tpm2_evictcontrol -C o -c "$TPM_HANDLE" 2>/dev/null || true
        tpm2_evictcontrol -C o -c 0x81010000 2>/dev/null || true
        tpm2_evictcontrol -C o -c 0x81010001 2>/dev/null || true
        tpm2_getcap handles-persistent

        # Create keyfile
        echo "Creating random keyfile..."
        dd if=/dev/urandom of=/tmp/keyfile bs=32 count=1

        # Check if already in LUKS
        echo "Checking LUKS slots..."

        # Add to LUKS
        echo "Adding keyfile to LUKS (you'll need to enter your current password)..."
        sudo cryptsetup luksAddKey "$LUKS_DEVICE" /tmp/keyfile || {
          echo "Note: If keyfile already exists in LUKS, continuing anyway..."
        }

        echo ""
        echo "Now for the fun part - fighting swtpm's memory errors..."
        echo "This WILL fail many times. Just let it run."
        echo ""

        # Try to seal the key (this is where we fight the memory errors)
        MAX_ATTEMPTS=50
        SUCCESS=0

        # First, check ALL persistent handles for existing sealed keys
        echo "Checking for existing sealed keys..."
        EXISTING_HANDLES=$(tpm2_getcap handles-persistent 2>/dev/null | grep -o '0x[0-9a-f]*' || true)

        for HANDLE in $EXISTING_HANDLES; do
          echo "Found persistent handle: $HANDLE"
          if tpm2_unseal -c "$HANDLE" 2>/dev/null | cmp -s /tmp/keyfile - 2>/dev/null; then
            echo "Key already sealed at $HANDLE! Testing LUKS..."
            if tpm2_unseal -c "$HANDLE" 2>/dev/null | sudo cryptsetup --test-passphrase open "$LUKS_DEVICE" --key-file=- 2>/dev/null; then
              echo ""
              echo "=== SUCCESS! ==="
              echo "TPM unlock already configured at handle $HANDLE"

              if [ "$HANDLE" != "$TPM_HANDLE" ]; then
                echo ""
                echo "NOTE: Key is at $HANDLE, not the configured $TPM_HANDLE"
                echo "Update your configuration to use: tpmHandle = \"$HANDLE\";"
              fi

              SUCCESS=1
              break
            fi
          fi
        done

        if [ $SUCCESS -eq 0 ]; then
          # Pick a temp handle different from target
          TEMP_HANDLE="0x81010001"
          if [ "$TPM_HANDLE" = "0x81010001" ]; then
            TEMP_HANDLE="0x81010002"
          fi

          for i in $(seq 1 $MAX_ATTEMPTS); do
            echo "Attempt $i/$MAX_ATTEMPTS..."

            # Every 5 attempts, restart swtpm to clear its memory
            if [ $((i % 5)) -eq 0 ]; then
              echo "Restarting swtpm to clear memory..."
              sudo systemctl restart swtpm
              sleep 2
              export TPM2TOOLS_TCTI="swtpm:host=localhost,port=2321"
              tpm2_startup -c || true
            fi

            # Clear transient objects
            tpm2_flushcontext -t 2>/dev/null || true

            # Check if we already have a primary persisted
            PRIMARY_EXISTS=0
            if tpm2_readpublic -c "$TEMP_HANDLE" -Q 2>/dev/null; then
              echo "Primary already persisted at $TEMP_HANDLE, reusing..."
              PRIMARY_EXISTS=1
            fi

            # Only create primary if we don't have one
            if [ $PRIMARY_EXISTS -eq 0 ]; then
              # Clear handles first
              tpm2_evictcontrol -C o -c "$TPM_HANDLE" -Q 2>/dev/null || true
              tpm2_evictcontrol -C o -c "$TEMP_HANDLE" -Q 2>/dev/null || true

              # Create and persist primary
              if ! tpm2_createprimary -C o -c primary.ctx -Q 2>/dev/null; then
                echo "Failed to create primary"
                continue
              fi

              if ! tpm2_evictcontrol -C o -c primary.ctx "$TEMP_HANDLE" -Q 2>/dev/null; then
                echo "Failed to persist primary"
                continue
              fi
              echo "Primary persisted at $TEMP_HANDLE"
            fi

            # Try to create and seal using the persistent primary
            if tpm2_create -C "$TEMP_HANDLE" -i /tmp/keyfile -r seal.priv -u seal.pub -Q 2>/dev/null; then
              if tpm2_load -C "$TEMP_HANDLE" -r seal.priv -u seal.pub -c seal.ctx -Q 2>/dev/null; then
                if tpm2_evictcontrol -C o -c seal.ctx "$TPM_HANDLE" -Q 2>/dev/null; then
                  # Clean up temp handle
                  tpm2_evictcontrol -C o -c "$TEMP_HANDLE" 2>/dev/null || true
                      echo "Key persisted at handle $TPM_HANDLE"

                      # Now test unsealing from persistent handle
                      if tpm2_unseal -c "$TPM_HANDLE" 2>/dev/null | cmp -s /tmp/keyfile -; then
                        echo "SUCCESS! Sealing works!"

                        # Final test with LUKS
                        if tpm2_unseal -c "$TPM_HANDLE" | sudo cryptsetup --test-passphrase open "$LUKS_DEVICE" --key-file=-; then
                        echo ""
                        echo "=== SUCCESS! ==="
                        echo "TPM-based LUKS unlock is configured!"
                        echo "Your key is sealed at TPM handle $TPM_HANDLE"
                        echo ""
                        echo "=== NEXT STEPS ==="
                        echo ""

                        # Check if already configured
                        CONFIG_FILE="/home/emet/nixconf/hosts/$(hostname)/configuration.nix"
                        if grep -q "tpmUnlock.*{" "$CONFIG_FILE" 2>/dev/null && \
                           grep -q "enable.*=.*true" "$CONFIG_FILE" 2>/dev/null && \
                           grep -q "$LUKS_DEVICE" "$CONFIG_FILE" 2>/dev/null && \
                           grep -q "$TPM_HANDLE" "$CONFIG_FILE" 2>/dev/null; then
                          echo "✓ Your configuration already has TPM unlock enabled!"
                          echo ""
                          echo "Just reboot and enjoy password-free boot!"
                        else
                          echo "To enable auto-unlock on boot, add this to your"
                          echo "/home/emet/nixconf/hosts/$(hostname)/configuration.nix:"
                          echo ""
                          echo "    apple = {"
                          echo "      enable = true;"
                          echo "      modelOverrides = \"T2\";"
                          echo "      tpmUnlock = {"
                          echo "        enable = true;"
                          echo "        luksDevice = \"$LUKS_DEVICE\";"
                          echo "        luksName = \"luks-rpool\";  # or your LUKS name"
                          echo "        tpmHandle = \"$TPM_HANDLE\";  # Handle where key was sealed"
                          echo "      };"
                          echo "    };"
                          echo ""
                          echo "Then run: sudo nh os switch ."
                          echo "After rebuild, your system will auto-unlock on boot!"
                        fi
                        echo ""

                        # Clean up
                        shred -u /tmp/keyfile
                        rm -f primary.ctx seal.* /tmp/test

                        exit 0
                      fi
                    fi
                  fi
                fi
              fi

            echo "Attempt $i failed (expected - swtpm has tiny memory), trying again..."
            sleep 1
          done

          if [ $SUCCESS -eq 0 ]; then
            echo ""
            echo "ERROR: Failed after $MAX_ATTEMPTS attempts"
            echo "You might need to run this script multiple times or do it manually"
          fi
        fi

        if [ $SUCCESS -eq 1 ]; then
          # Show next steps for successful configuration
          echo ""
          echo "=== NEXT STEPS ==="

          # Check if already configured
          if [ "${toString cfg.tpmUnlock.enable}" = "true" ]; then
            echo "✓ Your configuration already has TPM unlock enabled!"
            echo ""
            echo "Just reboot and enjoy password-free boot!"
          else
            echo "To enable auto-unlock on boot, update your configuration"
            echo "Then run: sudo nh os switch ."
          fi
        fi

        # Clean up
        shred -u /tmp/keyfile 2>/dev/null || true
        rm -f primary.ctx seal.* 2>/dev/null || true

        exit $([ $SUCCESS -eq 1 ] && echo 0 || echo 1)
      '')

      # Script for new T2 machines to auto-detect and show config
      (pkgs.writeShellScriptBin "apple-t2-tpm-config" ''
        #!${pkgs.bash}/bin/bash

        echo "=== TPM LUKS Configuration Detector ==="
        echo ""

        # Set up TPM connection
        export TPM2TOOLS_TCTI="swtpm:host=localhost,port=2321"

        # Check for existing sealed keys
        echo "Checking for existing TPM sealed keys..."
        SEALED_HANDLE=""
        for handle in $(tpm2_getcap handles-persistent 2>/dev/null | grep -o '0x[0-9a-f]*' || true); do
          # Try to unseal to check if it's a sealed key (will fail but shows type)
          if tpm2_readpublic -c "$handle" 2>/dev/null | grep -q "keyedhash"; then
            echo "Found sealed key at handle: $handle"
            SEALED_HANDLE="$handle"
            break
          fi
        done

        # Find LUKS devices
        LUKS_DEVICES=$(lsblk -o NAME,FSTYPE,UUID | grep crypto_LUKS | awk '{print "/dev/disk/by-uuid/" $3}')

        if [ -z "$LUKS_DEVICES" ]; then
          echo "ERROR: No LUKS encrypted devices found!"
          exit 1
        fi

        echo "Found LUKS device(s):"
        echo "$LUKS_DEVICES"
        echo ""

        # Use first device or let user choose
        LUKS_DEVICE=$(echo "$LUKS_DEVICES" | head -1)

        # Check if already configured
        CONFIG_FILE="/home/emet/nixconf/hosts/$(hostname)/configuration.nix"
        CONFIG_EXISTS=0

        if [ -n "$SEALED_HANDLE" ]; then
          if grep -q "tpmUnlock.*{" "$CONFIG_FILE" 2>/dev/null && \
             grep -q "enable.*=.*true" "$CONFIG_FILE" 2>/dev/null && \
             grep -q "$LUKS_DEVICE" "$CONFIG_FILE" 2>/dev/null && \
             grep -q "$SEALED_HANDLE" "$CONFIG_FILE" 2>/dev/null; then
            CONFIG_EXISTS=1
          fi
        fi

        if [ $CONFIG_EXISTS -eq 1 ]; then
          echo "✅ Configuration already set in $CONFIG_FILE!"
          echo ""
          echo "TPM unlock is configured with:"
          echo "  • LUKS device: $LUKS_DEVICE"
          echo "  • TPM handle: $SEALED_HANDLE"
          echo ""
          echo "Ready to reboot for auto-unlock!"
        else
          echo "Configuration for /home/emet/nixconf/hosts/$(hostname)/configuration.nix:"
          echo ""
          echo "    apple = {"
          echo "      enable = true;"
          echo "      modelOverrides = \"T2\";"
          echo "      tpmUnlock = {"
          echo "        enable = true;"
          echo "        luksDevice = \"$LUKS_DEVICE\";"
          echo "        luksName = \"luks-rpool\";  # Change if needed"

          if [ -n "$SEALED_HANDLE" ]; then
            echo "        tpmHandle = \"$SEALED_HANDLE\";  # Existing sealed key found!"
            echo "      };"
            echo "    };"
            echo ""
            echo "TPM key already sealed! Just add this config and rebuild."
          else
            echo "        tpmHandle = \"0x81010000\";  # Default - will be set by setup"
            echo "      };"
            echo "    };"
            echo ""
            echo "After adding this configuration:"
            echo "1. Run: sudo nh os switch ."
            echo "2. Run: apple-t2-tpm-setup"
            echo "3. Reboot and enjoy auto-unlock!"
          fi
        fi
      '')
    ];
  };
}