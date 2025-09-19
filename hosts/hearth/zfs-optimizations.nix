{ config, lib, pkgs, ... }:

{
  # ZFS kernel module optimization with 25% ARC
  boot.extraModprobeConfig = ''
    # ARC settings: 25% of system RAM (32 GB detected)
    options zfs zfs_arc_max=8589934592
    options zfs zfs_arc_min=8589934592
    options zfs zfs_prefetch_disable=0
    options zfs zfs_txg_timeout=5
    options zfs zfs_vdev_scrub_max_active=3
    options zfs zfs_vdev_sync_read_max_active=20
    options zfs zfs_vdev_sync_write_max_active=20
    options zfs zfs_dirty_data_max_percent=25
    options zfs zfs_vdev_async_read_max_active=3
    options zfs zfs_vdev_async_write_max_active=10
  '';

  # System tuning for ZFS performance
  boot.kernel.sysctl = {
    # Memory management for ZFS
    "vm.swappiness" = 1;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.dirty_expire_centisecs" = 6000;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.vfs_cache_pressure" = 50;

    # Network optimizations
    "net.core.rmem_default" = 262144;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_default" = 262144;
    "net.core.wmem_max" = 16777216;
    "net.core.netdev_max_backlog" = 5000;

    # File system optimizations
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
  };

  # TPM2 support for LUKS auto-unlock
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Enable systemd in initrd for TPM2 unlock
  boot.initrd.systemd.enable = true;

  # LUKS configuration with TPM2 support
  boot.initrd.luks.devices."luks-rpool" = {
    device = "/dev/nvme0n1p2";
    crypttabExtraOpts = [ "tpm2-device=auto" "tpm2-pcrs=0+2+7" ];
  };

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

  # Enable ZFS auto-import
  boot.zfs.devNodes = "/dev/disk/by-id";
  boot.zfs.forceImportRoot = false;
  boot.zfs.forceImportAll = false;

  # Networking with unique hostId
  networking.hostId = lib.mkDefault "3054d730";

  # No swap (as requested)
  swapDevices = [ ];

  # Enable periodic filesystem checks
  systemd.services.zfs-mount.enable = true;

  # ZFS-specific systemd services
  systemd.services.zfs-import-rpool = {
    description = "Import ZFS pool rpool";
    wantedBy = [ "zfs-import.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.zfs}/bin/zpool import -d /dev/disk/by-id -aN
    '';
  };

  # ZFS and performance monitoring tools
  environment.systemPackages = with pkgs; [
    zfs          # Keep zfs package here for safety
    nvme-cli
    lm_sensors
    pciutils
    usbutils
    tpm2-tools
  ];

  # Enable fstrim for all SSD filesystems
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };
}
