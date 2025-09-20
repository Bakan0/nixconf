{ config, lib, pkgs, inputs, ... }:
with lib;
let
  cfg = config.myNixOS.apple;
in {
  imports = [
    ./t2.nix  # T2-specific configuration
  ];

  options.myNixOS.apple = {
    modelOverrides = mkOption {
      type = types.str;
      default = "";
      description = "Apply model-specific overrides (e.g. T2 for MacBooks with T2 chip)";
    };
  };

  config = mkIf cfg.enable {
    # General Apple hardware support (keyboards, trackpads, early boot)

    # Apple keyboard function key behavior (applies to all Apple keyboards)
    boot.kernelParams = lib.mkAfter [
      "hid_apple.fnmode=2"  # Use F-keys as function keys by default
      "hid_apple.swap_fn_leftctrl=1"  # Swap fn and left ctrl keys
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

    environment.systemPackages = with pkgs; [
      lm_sensors
      brightnessctl
      macchanger     # Useful for managing MAC addresses on Apple hardware
    ];
  };
}