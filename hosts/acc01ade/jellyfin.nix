{ config, pkgs, lib, ... }: {
  networking.firewall.allowedTCPPorts = [ 8096 ];

  services.jellyfin = {
    enable = true;
    dataDir = "/data/jellyfin";
    configDir = "/data/jellyfin/config";
    cacheDir = "/data/jellyfin/cache";
    logDir = "/data/jellyfin/log";
    user = "jellyfin";
    group = "jellyfin";
  };

  # Ensure jellyfin data directories exist
  systemd.tmpfiles.rules = [
    "d /data/jellyfin 0755 jellyfin jellyfin -"
    "d /data/jellyfin/config 0755 jellyfin jellyfin -"
    "d /data/jellyfin/cache 0755 jellyfin jellyfin -"
    "d /data/jellyfin/log 0755 jellyfin jellyfin -"
    # Create media folders in your existing NAS location
    "d /export/nas/media 0755 jellyfin jellyfin -"
    "d /export/nas/media/movies 0755 jellyfin jellyfin -"
    "d /export/nas/media/tv 0755 jellyfin jellyfin -"
    "d /export/nas/media/music 0755 jellyfin jellyfin -"
  ];

  users.users.jellyfin.extraGroups = [ "users" ];
}

