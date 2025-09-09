{ config, lib, pkgs, ... }:

{
  # ZFS kernel module optimization with 24GB ARC
  boot.kernelParams = [
    "zfs.zfs_arc_max=25769803776"  # 24GB max ARC size
  ];

  # Enable ZFS auto-import
  boot.zfs.devNodes = "/dev/disk/by-id";
  boot.zfs.forceImportRoot = false;
  boot.zfs.forceImportAll = false;

  # Networking with unique hostId
  networking.hostId = lib.mkDefault "5caff01d";

  # ZFS services with optimal settings
  services.zfs.autoScrub = {
    enable = true;
    interval = "monthly";
    pools = [ "rpool" ];
  };

  services.zfs.autoSnapshot = {
    enable = true;
    flags = "-k -p --utc";
    frequent = 8;   # 15-minute snapshots, keep 8 (2 hours)
    hourly = 48;    # Keep 48 hourly (2 days)
    daily = 14;     # Keep 14 daily (2 weeks)
    weekly = 8;     # Keep 8 weekly (2 months)
    monthly = 12;   # Keep 12 monthly (1 year)
  };

  # ZFS trim service for SSD optimization
  services.zfs.trim = {
    enable = true;
    interval = "weekly";
  };

  # Performance monitoring and ZFS tools
  environment.systemPackages = with pkgs; [
    zfs
    smartmontools
    iotop
    htop
    btop
    nvme-cli
    lm_sensors
    pciutils
    usbutils
  ];

  # Enable fstrim for all SSD filesystems
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # System tuning for ZFS performance
  boot.kernel.sysctl = {
    # Memory management for ZFS
    "vm.swappiness" = 1;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.dirty_expire_centisecs" = 6000;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.vfs_cache_pressure" = 50;
  };
}