{ config, lib, pkgs, inputs, ... }:
with lib;
let
  cfg = config.myNixOS.apple;
in {
  options.myNixOS.apple = {
    modelOverrides = mkOption {
      type = types.str;
      default = "";
      description = "Apply model-specific overrides (e.g. T2 for MacBooks with T2 chip)";
    };
  };

  config = mkIf cfg.enable {
  # Apple hardware support (keyboards, trackpads, early boot)
  # NOTE: For T2 Macs, also add to your host's configuration.nix:
  # imports = [ inputs.nixos-hardware.nixosModules.apple-t2 ];

  # Early boot modules for T2 devices (Apple keyboard/trackpad support in LUKS)
  boot.initrd.kernelModules = lib.optionals (cfg.modelOverrides == "T2") [
    "apple-bce"         # Apple BCE driver for T2 devices
    "snd"               # Sound support for T2
    "snd_pcm"           # PCM sound support for T2
  ];

  # TPM support for T2 chip
  boot.kernelModules = lib.optionals (cfg.modelOverrides == "T2") [
    "tpm_tis"           # TPM TIS driver
    "tpm_tis_core"      # TPM TIS core
  ];

  # Apple keyboard function key behavior (applies to all Apple keyboards)
  boot.kernelParams = [
    "hid_apple.fnmode=2"  # Use F-keys as function keys by default
    "hid_apple.swap_fn_leftctrl=1"  # Swap fn and left ctrl keys
  ] ++ lib.optionals (cfg.modelOverrides == "T2") [
    # T2 Mac specific fixes for WiFi and TPM
    "pci=nobbn"         # Fix DMA overflow for Broadcom WiFi on T2 Macs
    # Note: nixos-hardware already sets IOMMU params, we don't override
  ];

  # Kernel module configuration for Apple devices
  boot.extraModprobeConfig = ''
    # Apple keyboard configuration
    options hid_apple fnmode=2
    options hid_apple iso_layout=0
    options hid_apple swap_fn_leftctrl=1
  '';

  # Touchpad/trackpad support
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      disableWhileTyping = true;
    };
  };

  # MacBook-specific udev rules
  services.udev.extraRules = ''
    # Apple keyboard backlight
    SUBSYSTEM=="leds", KERNEL=="smc::kbd_backlight", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness"

    # Apple trackpad
    KERNEL=="mouse[0-9]*", ATTR{device/vendor}=="05ac", ATTR{device/product}=="030[0-9a-f]", ENV{ID_INPUT_TOUCHPAD}="1"
  '';

  # Enhanced fwupd configuration for Apple hardware
  services.fwupd = {
    # Note: Only stable LVFS repo enabled by default for safety
    # For testing firmware: sudo fwupdmgr enable-remote lvfs-testing
    uefiCapsuleSettings = {
      DisableCapsuleUpdateOnDisk = false;
      EnableQuirks = true;
    };
  };

  # Additional firmware support for Apple devices
  hardware.firmware = with pkgs; [
    wireless-regdb  # Wireless regulatory database for proper WiFi/BT firmware
  ];


  # TouchBar support for MacBook Pro with Touch Bar (T2 models)
  hardware.apple.touchBar = lib.mkIf (cfg.modelOverrides == "T2") {
    enable = true;
    settings = {
      MediaLayerDefault = true;      # Show media controls by default
      ShowButtonOutlines = false;    # Cleaner look without button outlines
      EnablePixelShift = true;       # Prevent OLED burn-in
    };
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
    brightnessctl
    macchanger     # Useful for managing MAC addresses on Apple hardware
  ] ++ lib.optionals (cfg.modelOverrides == "T2") [
    tiny-dfr       # TouchBar daemon for T2 MacBook Pro models
  ];
  };
}