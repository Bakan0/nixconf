{
  pkgs,
  lib,
  ...
}: {
  # System-wide nixpkgs configuration
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Nix experimental features
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Automatic generation cleanup - keep max 17 generations  
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  
  # Automatically clean up old boot entries (keep 17 generations)
  boot.loader.systemd-boot.configurationLimit = 17;

  # US Central time zone
  time.timeZone = lib.mkDefault "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = { 
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };  

  console = {
    earlySetup = true;
    font = "sun12x22";
    useXkbConfig = true;
  };

  security.rtkit.enable = true;

  environment.etc.hosts.mode = "0644";

  # Essential system services
  services = {
    # GVFS for file manager integration
    gvfs.enable = true;

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };

    upower.enable = true;
  };

  # Enable basic system features
  myNixOS.powerManagement.enable = lib.mkDefault true;

  # Nix optimizations
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.dconf.enable = true;
  security.polkit.enable = true;

  # Essential system packages
  environment.systemPackages = with pkgs; [
    curl
    git
    nh
    nix-output-monitor  
    tmux
    unzip
    vim
    wget  
    zip
  ];
}