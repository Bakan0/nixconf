{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.egpu-amd;
in {
  options.myNixOS.egpu-amd = {
    enableHotplug = mkOption {
      type = types.bool;
      default = true;
      description = "Enable automatic eGPU hotplug detection and setup";
    };

    enableNotifications = mkOption {
      type = types.bool;
      default = true;
      description = "Enable desktop notifications for eGPU events";
    };
  };

  config = mkIf cfg.enable {
    # Essential kernel modules for Intel + AMD eGPU
    boot.kernelModules = [ "thunderbolt" "i915" "amdgpu" ];

    # Kernel parameters for Intel GPU + AMD eGPU support
    boot.kernelParams = [
      # Intel GPU support (ensure it loads first)
      "i915.modeset=1"

      # PCI bus reservation for Thunderbolt hotplug
      "pci=hpbussize=0x30"
      "pci=realloc"
      "pcie_ports=native"
      "pcie_aspm=off"
      "pci=noaer"

      # AMD eGPU support
      "amdgpu.si_support=1"
      "amdgpu.cik_support=1" 
      "radeon.si_support=0"
      "radeon.cik_support=0"
      "modprobe.blacklist=radeon"
      "amdgpu.exp_hw_support=1"

      # Thunderbolt debugging
      "pciehp.pciehp_debug=1"
      "thunderbolt.dyndbg=+p"
    ];

    # Environment variables for proper GPU support
    environment.sessionVariables = {
      # Intel GPU (default)
      LIBVA_DRIVER_NAME = "iHD";
      GBM_BACKEND = "i915";

      # AMD eGPU variables (from Discord user's working setup)
      LIBVA_DRIVER_NAME_AMD = "radeonsi";
      VDPAU_DRIVER = "radeonsi";
      GBM_BACKEND_AMD = "radeonsi";
    };

    # Hardware graphics support for both Intel and AMD
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # Intel GPU support (gpuConfigs.intel.extraPackages)
        intel-media-driver
        vaapiIntel

        # AMD eGPU support (enhanced from gpuConfigs.amd)
        mesa.drivers         # Includes AMD VAAPI
        libvdpau-va-gl       # VDPAU-to-VAAPI bridge
        amdvlk               # AMD Vulkan
        rocmPackages.clr.icd # OpenCL
        rocmPackages.clr
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        vaapiIntel
        amdvlk
        mesa.drivers
      ];
    };

    # AMD GPU hardware support
    hardware.amdgpu = {
      initrd.enable = false;  # Don't load at initrd - hotplug only
      opencl.enable = true;
      amdvlk.enable = true;
    };

    # Thunderbolt security for eGPU
    services.hardware.bolt.enable = true;

    # udev rules for proper GPU ordering and eGPU hotplug
    services.udev.extraRules = ''
      # Force Intel GPU to be card0 (primary)
      SUBSYSTEM=="drm", KERNEL=="card*", ATTRS{vendor}=="0x8086", ENV{ID_PATH_TAG}="card0"

      # AMD eGPU hotplug detection
      SUBSYSTEM=="thunderbolt", ATTR{device_name}=="Razer Core X*", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-connect@%k.service"

      # AMD GPU PCI hotplug
      SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0x030000", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-amd-setup.service"

      # Set permissions for eGPU access
      SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", MODE="0666", GROUP="video"

      # Force RX 580 to use amdgpu driver
      SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{device}=="0x67df", DRIVER=="", ATTR{driver_override}="amdgpu"

      # Thunderbolt authorization for Razer devices
      SUBSYSTEM=="thunderbolt", ATTR{vendor}=="0x1532", ATTR{authorized}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-authorize@%k.service"
    '';

    # Thunderbolt device connection handler
    systemd.services."egpu-connect@" = mkIf cfg.enableHotplug {
      description = "AMD eGPU Thunderbolt Connection Handler";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "egpu-connect" ''
          #!/bin/sh
          echo "AMD eGPU Thunderbolt device connected: $1" | ${pkgs.systemd}/bin/systemd-cat -t egpu-handler
          sleep 3
          if [ -f "/sys/bus/thunderbolt/devices/$1/authorized" ]; then
            echo 1 > /sys/bus/thunderbolt/devices/$1/authorized || true
          fi
          ${optionalString cfg.enableNotifications ''
            ${pkgs.libnotify}/bin/notify-send "eGPU" "AMD eGPU Thunderbolt device connected" || true
          ''}
        ''}";
      };
    };

    # Thunderbolt authorization service
    systemd.services."egpu-authorize@" = mkIf cfg.enableHotplug {
      description = "Authorize Thunderbolt eGPU device";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "egpu-authorize" ''
          #!/bin/sh
          echo "Authorizing Thunderbolt device: $1" | ${pkgs.systemd}/bin/systemd-cat -t egpu-auth
          if [ -f "/sys/bus/thunderbolt/devices/$1/authorized" ]; then
            echo 1 > /sys/bus/thunderbolt/devices/$1/authorized
          fi
        ''}";
      };
    };

    # AMD GPU setup service
    systemd.services."egpu-amd-setup" = mkIf cfg.enableHotplug {
      description = "AMD eGPU Setup Service";
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "egpu-amd-setup" ''
          #!/bin/sh
          echo "AMD eGPU detected, setting up..." | ${pkgs.systemd}/bin/systemd-cat -t egpu-amd-setup

          # Wait for device to be ready
          sleep 5

          # Restart kanshi to reconfigure displays
          ${pkgs.systemd}/bin/systemctl --user restart kanshi.service || true

          ${optionalString cfg.enableNotifications ''
            ${pkgs.libnotify}/bin/notify-send "eGPU" "AMD RX 580 eGPU is ready" || true
          ''}
        ''}";
      };
    };

    # Essential packages for eGPU management
    environment.systemPackages = with pkgs; [
      # GPU monitoring tools
      radeontop
      amdgpu_top
      intel-gpu-tools
      pciutils
      usbutils
      bolt
      mesa-demos
      vulkan-tools

      # AMD offload wrapper (Discord user's approach)
      (writeShellScriptBin "amd-offload" ''
        export DRI_PRIME=1
        export AMD_VULKAN_ICD=RADV
        export RADV_PERFTEST=aco
        export LIBVA_DRIVER_NAME=radeonsi
        export VDPAU_DRIVER=radeonsi
        exec "$@"
      '')

      # eGPU status checker
      (writeShellScriptBin "egpu-status" ''
        echo "=== GPU Devices ==="
        ${pciutils}/bin/lspci -nn | grep -E "(VGA|3D|Display)"
        echo
        echo "=== DRM Devices ==="
        ls -la /dev/dri/
        echo
        echo "=== AMD eGPU Status ==="
        if ${pciutils}/bin/lspci -nn | grep -q "1002:67df"; then
          echo "✅ AMD RX 580 eGPU detected"
          if [ -c "/dev/dri/card1" ]; then
            ${radeontop}/bin/radeontop -d /dev/dri/card1 -l 1 || echo "radeontop failed"
          else
            echo "⚠️  eGPU detected but no /dev/dri/card1"
          fi
        else
          echo "❌ No AMD eGPU detected"
        fi
        echo
        echo "=== Intel GPU Status ==="
        if [ -c "/dev/dri/card0" ]; then
          echo "✅ Intel GPU available at /dev/dri/card0"
        else
          echo "❌ No Intel GPU at /dev/dri/card0"
        fi
      '')

      # Immersed launcher with GPU selection
      (writeShellScriptBin "immersed-intel" ''
        export DRI_PRIME=0
        export LIBVA_DRIVER_NAME=iHD
        echo "Starting Immersed with Intel GPU..."
        exec immersed "$@"
      '')

      (writeShellScriptBin "immersed-amd" ''
        if ${pciutils}/bin/lspci -nn | grep -q "1002:67df"; then
          export DRI_PRIME=1
          export AMD_VULKAN_ICD=RADV
          export RADV_PERFTEST=aco
          export LIBVA_DRIVER_NAME=radeonsi
          export VDPAU_DRIVER=radeonsi
          echo "Starting Immersed with AMD eGPU..."
          exec immersed "$@"
        else
          echo "❌ No AMD eGPU detected - use immersed-intel instead"
          exit 1
        fi
      '')
    ];

    # Add user to necessary groups for GPU access
    users.users = mkIf (config.myNixOS.home-users ? "emet") {
      emet.extraGroups = [ "video" "render" ];
    };

    # Ensure proper permissions for Thunderbolt management
    security.sudo.extraRules = [{
      users = [ "emet" ];
      commands = [{
        command = "${pkgs.bolt}/bin/boltctl";
        options = [ "NOPASSWD" ];
      }];
    }];

    # Power management
    powerManagement.enable = true;
  };
}

