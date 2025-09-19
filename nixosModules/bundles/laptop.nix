{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    acpi           # ACPI utilities for battery/power info
    brightnessctl  # Control display brightness
  ];

  # Enable battery management for laptops
  myNixOS.batteryManagement.enable = true;
}