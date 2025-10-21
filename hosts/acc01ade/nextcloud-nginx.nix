{ config, pkgs, lib, ... }: {
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  environment.etc."nextcloud-admin-pass".text = "D3F417-changeme2435";

  # Add occ wrapper script
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "occ" ''
      sudo -u nextcloud php /data/nextcloud/occ "$@"
    '')
  ];

  # PostgreSQL
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    dataDir = "/data/postgresql";
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32;
    hostName = "nc.databender.io";
    datadir = "/data/nextcloud";
    database.createLocally = true;
    extraApps = {
      inherit (config.services.nextcloud.package.packages.apps) forms;
    };
    extraAppsEnable = true;
    config = {
      adminpassFile = "/etc/nextcloud-admin-pass";
      dbtype = "pgsql";
    };
    https = true;
    maxUploadSize = "60G";
    autoUpdateApps = {
      enable = true;
      startAt = "05:00:00";
    };
    configureRedis = true;
    caching.apcu = true;
    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
      "opcache.memory_consumption" = "512";
      "opcache.max_accelerated_files" = "10000";
      "apc.enable_cli" = "1";
    };
    settings = {
      default_phone_region = "US";
      trusted_proxies = [ "127.0.0.1" ];
      enable_previews = true;
      preview_max_x = 2048;
      preview_max_y = 2048;
      enabledPreviewProviders = [
        "OC\\Preview\\BMP"
        "OC\\Preview\\GIF"
        "OC\\Preview\\JPEG"
        "OC\\Preview\\Krita"
        "OC\\Preview\\MarkDown"
        "OC\\Preview\\MP3"
        "OC\\Preview\\OpenDocument"
        "OC\\Preview\\PNG"
        "OC\\Preview\\TXT"
        "OC\\Preview\\XBitmap"
        "OC\\Preview\\HEIC"
      ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      ${config.services.nextcloud.hostName} = {
        forceSSL = true;
        enableACME = true;
      };

      # Add Jellyfin virtual host
      "jelly.databender.io" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_buffering off;
          '';
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    certs = {
      ${config.services.nextcloud.hostName}.email = "IamJohnMichael@pm.me";
      "jelly.databender.io".email = "IamJohnMichael@pm.me";
    };
  };

  # Simplified service dependencies
  systemd.services.nextcloud-setup = {
    requires = [ "postgresql.service" ];
    after = [ "postgresql.service" ];
  };

  systemd.services.phpfpm-nextcloud = {
    after = [ "nextcloud-setup.service" ];
  };

  # Ensure PostgreSQL directory exists with proper permissions
  systemd.tmpfiles.rules = [
    "d /data/postgresql 0700 postgres postgres -"
  ];
}

