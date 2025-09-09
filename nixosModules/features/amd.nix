{ config, lib, pkgs, inputs, ... }:
with lib;
let cfg = config.myNixOS.amd;
in {
  # OPTIONS AT TOP LEVEL:
  options.myNixOS.amd = {
    supergfxMode = mkOption {
      type = types.enum [ "Integrated" "Hybrid" "AsusMuxDgpu" ];
      default = "Integrated";
      description = "SuperGFX graphics mode - determines which AMD settings to apply";
    };
    
    conservativePowerManagement = mkOption {
      type = types.bool;
      default = false;
      description = "Enable conservative power management to prevent ZFS conflicts (may hurt performance)";
    };
  };

  # CONFIG AFTER OPTIONS:
  config = mkIf cfg.enable (mkMerge [
    # COMMON SETTINGS (All modes: Integrated, Hybrid, AsusMuxDgpu)
    {
      # AMD firmware and hardware support (needed for all AMD hardware)
      hardware = {
        enableRedistributableFirmware = true;
        firmware = with pkgs; [ linux-firmware ];
        graphics = {
          enable = true;
          enable32Bit = true;
          extraPackages = with pkgs; [
            # AMD GPU drivers
            mesa  # Full mesa package with drivers
            amdvlk  # AMD Vulkan driver
            
            # Universal VAAPI hardware acceleration drivers
            libva
            libva-vdpau-driver
            libvdpau-va-gl
            vaapiVdpau  # VAAPI VDPAU driver
          ];
          
          extraPackages32 = with pkgs.driversi686Linux; [
            mesa
            amdvlk
          ];
        };
      };

      # Universal GPU debugging and testing tools
      environment.systemPackages = with pkgs; [
        mesa-demos
        vulkan-tools
        glxinfo
        libva-utils        # vainfo for VAAPI debugging
      ];
    }

    # INTEGRATED MODE SETTINGS (iGPU only)
    (mkIf (cfg.supergfxMode == "Integrated") {
      # Minimal settings for iGPU-only operation
      boot.kernelModules = [ "amdgpu" ];
    })

    # HYBRID MODE SETTINGS (iGPU + dGPU)
    (mkIf (cfg.supergfxMode == "Hybrid") {
      boot = {
        kernelParams = [
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
      };

      # Hybrid-specific VAAPI environment variables
      environment.sessionVariables = {
        VAAPI_DISABLE_VBV = "1";      # Hybrid mode encoding fix
        LIBVA_MESSAGING_LEVEL = "2";  # Debug hybrid issues
      };

      # ROCm support for compute workloads
      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr.icd
        rocmPackages.rocminfo
        rocmPackages.rocm-runtime
      ];

      systemd.tmpfiles.rules = [
        "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
      ];

      environment.systemPackages = with pkgs; [
        radeontop
        rocmPackages.rocminfo
      ];
    })

    # ASUSMUXDGPU MODE SETTINGS (dGPU only via MUX switch)
    (mkIf (cfg.supergfxMode == "AsusMuxDgpu") {
      boot = {
        kernelParams = [
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
      };

      # Full ROCm support for dGPU-only compute workloads
      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr.icd
        rocmPackages.rocminfo
        rocmPackages.rocm-runtime
      ];

      systemd.tmpfiles.rules = [
        "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
      ];

      environment.systemPackages = with pkgs; [
        radeontop
        rocmPackages.rocminfo
      ];
    })
  ]);
}

