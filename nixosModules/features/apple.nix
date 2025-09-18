{ config, lib, pkgs, ... }:

{
  # Apple device support (MacBook keyboards, trackpads, etc.)
  # Provides Apple-specific drivers and configuration
  # Note: Bluetooth, audio, and firmware are handled by general-desktop bundle

  # Enable Apple HID drivers for keyboard and trackpad
  boot.kernelModules = [
    "hid-apple"         # Apple HID devices (keyboard, trackpad)
    "applesmc"          # Apple System Management Controller
  ];

  # Apple keyboard function key behavior
  boot.kernelParams = [
    "hid_apple.fnmode=2"  # Use F-keys as function keys by default
    "acpi_osi=Linux"
    "acpi_backlight=vendor"
  ];

  # Kernel module configuration for Apple devices
  boot.extraModprobeConfig = ''
    # Apple keyboard configuration
    options hid_apple fnmode=2
    options hid_apple iso_layout=0

    # Apple SMC sensor configuration
    options applesmc debug=1
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

  # Useful utilities for Apple hardware monitoring
  environment.systemPackages = with pkgs; [
    lm_sensors
    brightnessctl
    macchanger     # Useful for managing MAC addresses on Apple hardware
  ];
}