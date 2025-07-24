{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.egpu;

  # Auto-detect integrated GPU vendor
  integratedGpu = if (builtins.pathExists "/sys/class/drm/card0/device/vendor") then
    let vendor = builtins.readFile "/sys/class/drm/card0/device/vendor";
    in if (lib.hasPrefix "0x8086" vendor) then "intel"
       else if (lib.hasPrefix "0x1002" vendor) then "amd"
       else "unknown"
  else "intel"; # fallback

  # GPU-specific configurations
  gpuConfigs = {
    intel = {
      libvaDriver = "iHD";
      gbmBackend = "i915";
      extraPackages = with pkgs; [ intel-media-driver vaapiIntel ];
      kernelParams = [ "i915.modeset=1" ];
      drmDevice = "/dev/dri/card0";
    };
    amd = {
      libvaDriver = "radeonsi";
      gbmBackend = "radeonsi";
      extraPackages = with pkgs; [ mesa.drivers ];
      kernelParams = [ "amdgpu.modeset=1" ];
      drmDevice = "/dev/dri/card0";
    };
  };

  currentGpuConfig = gpuConfigs.${integratedGpu} or gpuConfigs.intel;
in {
  # Add additional options that myLib doesn't auto-generate
  options.myNixOS.egpu = {
    intelBusId = mkOption {
      type = types.str;
      default = "PCI:0:2:0";
      description = "Intel GPU bus ID (auto-detected if possible)";
    };

    amdBusId = mkOption {
      type = types.str;
      default = "PCI:0:6:0";
      description = "AMD GPU bus ID";
    };

    nvidiaBusId = mkOption {
      type = types.str;
      default = "PCI:1:0:0";
      description = "NVIDIA eGPU bus ID (typically changes when connected)";
    };

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
    # Only load Thunderbolt module by default - NVIDIA drivers loaded conditionally
    boot.kernelModules = [ "thunderbolt" ];

    # Kernel parameters for eGPU support (removed intel_iommu=on)
    boot.kernelParams = currentGpuConfig.kernelParams ++ [
      "nvidia-drm.modeset=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];

    # Hardware support for eGPU
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      open = false; # Use proprietary driver for better eGPU support
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      # prime configuration for hybrid graphics
      prime = mkMerge [
        {
          offload = {
            enable = true;
            enableOffloadCmd = true;
          };
        }
        (mkIf (integratedGpu == "intel") {
          intelBusId = cfg.intelBusId;
          nvidiaBusId = cfg.nvidiaBusId;
        })
        (mkIf (integratedGpu == "amd") {
          amdgpuBusId = cfg.amdBusId;
          nvidiaBusId = cfg.nvidiaBusId;
        })
      ];
    };

    # Enable OpenGL for eGPU
    hardware.graphics = {
      enable = true;
      extraPackages = currentGpuConfig.extraPackages ++ (with pkgs; [
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau-va-gl
      ]);
    };

    # Thunderbolt security for eGPU
    services.hardware.bolt.enable = true;

    # udev rules for eGPU hotplug with conditional driver loading
    services.udev.extraRules = mkIf cfg.enableHotplug ''
      # Razer Core X eGPU detection (Vendor ID: 1532, varies by model)
      SUBSYSTEM=="thunderbolt", ATTR{device_name}=="Razer Core X*", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-connect@%k.service"

      # Generic Thunderbolt eGPU detection
      SUBSYSTEM=="thunderbolt", ATTR{device_name}=="*eGPU*", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-connect@%k.service"

      # NVIDIA GPU hotplug in eGPU - Load drivers when detected
      SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-nvidia-driver-load.service egpu-nvidia-setup.service"

      # Set permissions for eGPU access
      SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", MODE="0666", GROUP="video"

      # Thunderbolt authorization for Razer devices
      SUBSYSTEM=="thunderbolt", ATTR{vendor}=="0x1532", ATTR{authorized}="0", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-authorize@%k.service"

      # Generic Thunderbolt eGPU authorization
      SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", TAG+="systemd", ENV{SYSTEMD_WANTS}="egpu-authorize@%k.service"
    '';

    # Service to load NVIDIA drivers only when NVIDIA GPU is detected
    systemd.services."egpu-nvidia-driver-load" = mkIf cfg.enableHotplug {
      description = "Load NVIDIA eGPU Drivers";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "egpu-nvidia-driver-load" ''
          #!/bin/sh
          echo "Loading NVIDIA eGPU drivers..." | ${pkgs.systemd}/bin/systemd-cat -t egpu-nvidia-driver
          ${pkgs.kmod}/bin/modprobe nvidia || true
          ${pkgs.kmod}/bin/modprobe nvidia_modeset || true
          ${pkgs.kmod}/bin/modprobe nvidia_uvm || true
          ${pkgs.kmod}/bin/modprobe nvidia_drm || true
        ''}";
      };
    };

    # Systemd service for eGPU connection handling
    systemd.services."egpu-connect@" = mkIf cfg.enableHotplug {
      description = "eGPU Connection Handler";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "egpu-connect" ''
          #!/bin/sh
          # Log eGPU connection
          echo "eGPU Thunderbolt device connected: $1" | ${pkgs.systemd}/bin/systemd-cat -t egpu-handler

          # Wait for device to settle
          sleep 3

          # Authorize the Thunderbolt device
          if [ -f "/sys/bus/thunderbolt/devices/$1/authorized" ]; then
            echo 1 > /sys/bus/thunderbolt/devices/$1/authorized || true
          fi

          ${optionalString cfg.enableNotifications ''
            # Notify user
            ${pkgs.libnotify}/bin/notify-send "eGPU" "Thunderbolt eGPU device connected" || true
          ''}
        ''}";
      };
    };

    # Systemd service for NVIDIA GPU setup when detected
    systemd.services."egpu-nvidia-setup" = mkIf cfg.enableHotplug {
      description = "eGPU NVIDIA GPU Setup";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "egpu-nvidia-setup" ''
          #!/bin/sh
          # Log NVIDIA GPU detection
          echo "NVIDIA eGPU detected, setting up drivers" | ${pkgs.systemd}/bin/systemd-cat -t egpu-nvidia

          # Reload NVIDIA modules for eGPU
          ${pkgs.kmod}/bin/modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia || true
          sleep 2
          ${pkgs.kmod}/bin/modprobe nvidia nvidia_uvm nvidia_modeset nvidia_drm

          # Update display detection
          ${pkgs.systemd}/bin/systemctl --user restart kanshi.service || true

          ${optionalString cfg.enableNotifications ''
            # Notify user
            ${pkgs.libnotify}/bin/notify-send "eGPU" "NVIDIA eGPU is ready for use" || true
          ''}
        ''}";
      };
    };

    # Thunderbolt authorization service
    systemd.services."egpu-authorize@" = mkIf cfg.enableHotplug {
      description = "Authorize eGPU Thunderbolt Device";
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

    # Additional packages for eGPU management
    environment.systemPackages = with pkgs; [
      linuxPackages.nvidia_x11
      nvtopPackages.full
      intel-gpu-tools # For Intel GPU monitoring
      radeontop # For AMD GPU monitoring (if applicable)
      pciutils # For lspci
      usbutils # For lsusb
      bolt # For bolt management

      # SAFE: Offload command wrapper (only when explicitly called)
      (writeShellScriptBin "nvidia-offload" ''
        export __NV_PRIME_RENDER_OFFLOAD=1
        export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only
        export CUDA_VISIBLE_DEVICES=0
        exec "$@"
      '')

      # SAFE: eGPU session launcher with detection
      (writeShellScriptBin "nvidia-egpu-session" ''
        if ${pciutils}/bin/lspci | grep -q "NVIDIA"; then
          export __NV_PRIME_RENDER_OFFLOAD=1
          export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export __VK_LAYER_NV_optimus=NVIDIA_only
          export CUDA_VISIBLE_DEVICES=0
          export LIBVA_DRIVER_NAME=${currentGpuConfig.libvaDriver}
          export GBM_BACKEND=${currentGpuConfig.gbmBackend}
          export OPENCL_VENDOR_PATH="/run/opengl-driver/etc/OpenCL/vendors"
          export VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
          export NVIDIA_DRIVER_CAPABILITIES=all
          export NVIDIA_VISIBLE_DEVICES=all
          echo "Starting session with NVIDIA eGPU..."
          exec "$@"
        else
          echo "No NVIDIA eGPU detected, using integrated graphics"
          exec "$@"
        fi
      '')

      # eGPU status checker
      (writeShellScriptBin "egpu-status" ''
        echo "=== System Information ==="
        echo "Integrated GPU: ${integratedGpu}"
        echo "DRM Device: ${currentGpuConfig.drmDevice}"
        echo
        echo "=== Thunderbolt Devices ==="
        ${bolt}/bin/boltctl list
        echo
        echo "=== GPU Devices ==="
        ${pciutils}/bin/lspci | grep -E "(VGA|3D|Display)"
        echo
        echo "=== NVIDIA Status ==="
        if command -v nvidia-smi >/dev/null 2>&1; then
          nvidia-smi -L
          echo
          nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
        else
          echo "NVIDIA driver not loaded or no eGPU connected"
        fi
        echo
        echo "=== Environment Variables ==="
        env | grep -E "(NVIDIA|CUDA|__NV_|LIBVA|GBM)" | sort
      '')

      # eGPU benchmark tool
      (writeShellScriptBin "egpu-benchmark" ''
        echo "Running eGPU benchmark..."
        if command -v nvidia-smi >/dev/null 2>&1; then
          echo "=== GPU Information ==="
          nvidia-smi
          echo
          echo "=== Running glxgears with eGPU ==="
          nvidia-offload glxgears -info
        else
          echo "No NVIDIA eGPU detected"
          exit 1
        fi
      '')

      # SAFE: Immersed launcher with eGPU detection
      (writeShellScriptBin "immersed-egpu" ''
        if ${pciutils}/bin/lspci | grep -q "NVIDIA"; then
          echo "Starting Immersed with NVIDIA eGPU acceleration..."
          export __NV_PRIME_RENDER_OFFLOAD=1
          export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
          export __GLX_VENDOR_LIBRARY_NAME=nvidia
          export __VK_LAYER_NV_optimus=NVIDIA_only
          export CUDA_VISIBLE_DEVICES=0
          exec immersed "$@"
        else
          echo "No NVIDIA eGPU detected, starting Immersed with integrated graphics"
          exec immersed "$@"
        fi
      '')
    ];

    # Immersed-specific optimizations
    environment.etc."immersed-egpu.conf".text = ''
      # Immersed eGPU Configuration
      # Use this with: immersed-egpu or nvidia-offload immersed
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      export CUDA_VISIBLE_DEVICES=0
      export NVIDIA_DRIVER_CAPABILITIES=all
      export NVIDIA_VISIBLE_DEVICES=all
    '';

    # Add user to necessary groups for GPU access
    users.users = mkIf (config.myNixOS.home-users ? "emet") {
      emet.extraGroups = [ "video" "render" ];
    };

    # Enable necessary services
    services.xserver.videoDrivers = [ "nvidia" ];

    # Power management for eGPU
    powerManagement.enable = true;

    # Ensure proper permissions for Thunderbolt
    security.sudo.extraRules = [{
      users = [ "emet" ];
      commands = [{
        command = "${pkgs.bolt}/bin/boltctl";
        options = [ "NOPASSWD" ];
      }];
    }];
  };
}

