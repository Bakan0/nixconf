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
    # Modern D-Bus implementation - superior performance and security
    dbus = {
      enable = true;
      implementation = "broker";
    };

    # GVFS for file manager integration
    gvfs.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # SSH daemon for remote access
    openssh.enable = true;

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
  myNixOS.tpm2.enable = lib.mkDefault true;  # TPM2 support for LUKS auto-unlock

  # Nix optimizations
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.dconf.enable = true;
  security.polkit.enable = true;
  
  # GPG agent with SSH support
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Essential system packages
  environment.systemPackages = with pkgs; [
    bc          # CLI calculator
    colorls     # Colorized ls
    curl
    dnsutils    # dig, nslookup - essential for servers
    eza         # Better ls replacement
    fastfetch   # System information tool
    fd          # Fast file finder
    home-manager # For debugging home-manager activation issues
    file        # File type detection
    fwupd       # Firmware update daemon
    git
    htop        # Process monitor - essential for servers
    jq          # JSON processor for scripts
    lm_sensors  # Hardware monitoring for servers
    lsof        # List open files - debugging essential
    neofetch    # System info display
    nh          # Nix helper
    nix-output-monitor
    ntfs3g      # NTFS filesystem support
    openssl     # Crypto tools often needed system-wide
    ripgrep     # Fast grep replacement
    tmux
    tree        # Directory listing
    unrar       # Extract RAR archives
    unzip
    vim
    wget
    zip         # Archive creation
    zstd        # Compression for xfer-* scripts
  ];
}