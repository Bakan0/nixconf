{pkgs, ...}: {
  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;

      # ZFS-related settings
      show_disks = true;
      zfs_arc_cached = true;  # Count ZFS ARC as cached memory instead of used
      zfs_hide_datasets = false;  # Show ZFS datasets
      disk_free_priv = true;  # Use privileged mode for disk info

      # Memory display
      mem_graphs = true;
      mem_below_net = false;
      swap_disk = true;
      show_swap = true;
    };
  };
}
