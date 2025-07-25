{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.amd;
in {
  # OPTIONS AT TOP LEVEL:
  options.myNixOS.amd = {

    conservativePowerManagement = mkOption {
      type = types.bool;
      default = false;
      description = "Enable conservative power management to prevent ZFS conflicts (may hurt performance)";
    };
  };

  # CONFIG AFTER OPTIONS:
  config = mkIf cfg.enable {
    # AMD GPU kernel parameters and modules
    boot = {
      kernelParams = [
        "amd_iommu=on"
        "iommu=pt"
        "amdgpu.si_support=1"
        "amdgpu.cik_support=1" 
        "radeon.si_support=0"
        "radeon.cik_support=0"
        "swiotlb=65536"
        "amdgpu.noretry=0"
        "amdgpu.lockup_timeout=10000"
        "amdgpu.gpu_recovery=1"
        "pci=realloc"           # Reallocate PCI resources
      ] ++ optionals cfg.conservativePowerManagement [
        "amd_pstate=passive"
        "processor.max_cstate=2"
      ];

      kernelModules = [ "amdgpu" ];
      initrd.kernelModules = [ "amdgpu" ];
    };

    # AMD firmware and hardware support
    hardware = {
      enableRedistributableFirmware = true;
      firmware = with pkgs; [ linux-firmware ];
      graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          rocmPackages.clr.icd
          rocmPackages.rocminfo
          rocmPackages.rocm-runtime
        ];
      };
    };

    # ROCm support
    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];

    # AMD monitoring tools
    environment.systemPackages = with pkgs; [
      radeontop
      rocmPackages.rocminfo
      mesa-demos
      vulkan-tools
      glxinfo
    ];
  };
}

