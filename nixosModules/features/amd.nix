{ config, lib, pkgs, inputs, ... }:
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
        # FIXED: Use minimal parameters like the working ISO
        "nohibernate"                       # From working ISO
        "amdgpu.noretry=0"                  # Keep essential recovery params
        "amdgpu.lockup_timeout=10000"       # Keep essential recovery params
        "amdgpu.gpu_recovery=1"             # Keep essential recovery params
      ] ++ optionals cfg.conservativePowerManagement [
        "amd_pstate=passive"
        "processor.max_cstate=2"
        "amdgpu.runpm=0"                    # Disable runtime PM conflicts
        "amdgpu.bapm=0"                     # Disable bidirectional application power management
        "amdgpu.dc=1"                       # Force display core (sometimes helps)
        "amdgpu.audio=1"                    # Ensure audio doesn't interfere
      ];

      kernelModules = [ "amdgpu" ];

      # CRITICAL FIX: Removed initrd.kernelModules - this was breaking iGPU ROM access
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

    # VAAPI environment variables for Hybrid mode encoding fix
    environment.sessionVariables = {
      VAAPI_DISABLE_VBV = "1";
      LIBVA_MESSAGING_LEVEL = "2";
    };

    # ROCm support
    systemd.tmpfiles.rules = [
      "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];

    # AMD monitoring and hardware encoding tools
    environment.systemPackages = with pkgs; [
      radeontop
      rocmPackages.rocminfo
      mesa-demos
      vulkan-tools
      glxinfo
      libva-utils        # vainfo for VAAPI debugging
    ];
  };
}

