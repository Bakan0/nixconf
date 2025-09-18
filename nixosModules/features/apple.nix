{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Import nixos-hardware T2 support
    inputs.nixos-hardware.nixosModules.apple-t2
  ];
  # Apple T2 MacBook support (keyboards, trackpads, early boot)
  # Based on t2linux.org guides and your working notes
  # Complements nixos-hardware.apple-t2 with additional early boot support

  # Early boot modules for LUKS decryption (Apple keyboard/trackpad support)
  boot.initrd.kernelModules = [
    "apple-bce"         # Apple BCE driver for T2 devices
    "snd"               # Sound support
    "snd_pcm"           # PCM sound support
  ];

  # Apple keyboard function key behavior (if not set by nixos-hardware T2)
  boot.kernelParams = [
    "hid_apple.fnmode=2"  # Use F-keys as function keys by default
  ];

  # Kernel module configuration for Apple devices
  boot.extraModprobeConfig = ''
    # Apple keyboard configuration
    options hid_apple fnmode=2
    options hid_apple iso_layout=0
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

  # TouchBar support for MacBook Pro with Touch Bar
  hardware.apple.touchBar = {
    enable = true;
    settings = {
      MediaLayerDefault = true;      # Show media controls by default
      ShowButtonOutlines = false;    # Cleaner look without button outlines
      EnablePixelShift = true;       # Prevent OLED burn-in
    };
  };

  # Useful utilities for Apple hardware monitoring
  environment.systemPackages = with pkgs; [
    lm_sensors
    brightnessctl
    macchanger     # Useful for managing MAC addresses on Apple hardware
  ];
}