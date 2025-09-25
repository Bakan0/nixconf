{ config, lib, pkgs, ... }:
{
  # Intel graphics support - enable ONLY if Intel GPU hardware is present and used
  #
  # Enable for:
  # - Systems with Intel integrated graphics (most Intel laptops)
  # - Hybrid Intel + AMD/NVIDIA setups (where Intel GPU is active)
  # - Desktop systems where Intel iGPU is enabled in BIOS
  #
  # DO NOT enable for:
  # - Intel F-series CPUs (e.g. i5-13600KF) - these have no iGPU
  # - Systems where iGPU is disabled in BIOS
  # - Intel Xeon/server CPUs without graphics
  # - AMD CPU systems
  #
  # Check with: lspci | grep -i vga
  # If you see "Intel Corporation" with UHD/HD/Iris graphics, enable this module

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vaapiIntel
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };
}