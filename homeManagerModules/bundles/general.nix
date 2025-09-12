{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  myHomeManager.lf.enable = lib.mkDefault true;
  myHomeManager.yazi.enable = lib.mkDefault true;
  myHomeManager.nix-extra.enable = lib.mkDefault true;
  myHomeManager.btop.enable = lib.mkDefault true;
  # myHomeManager.nix-direnv.enable = lib.mkDefault true;
  myHomeManager.nix.enable = lib.mkDefault true;
  myHomeManager.git.enable = lib.mkDefault true;
  myHomeManager.nvim.enable = lib.mkDefault true;

  myHomeManager.stylix.enable = lib.mkDefault true;

  # myHomeManager.bottom.enable = lib.mkDefault true;

  programs.home-manager.enable = true;

  programs.lazygit.enable = true;
  programs.bat.enable = true;

  home.packages = with pkgs; [
    nil

    pistol
    file
    p7zip
    unzip
    zip
    libqalculate
    imagemagick
    killall
    pamixer
    alsa-utils
    rofi-bluetooth

    fzf
    htop
    lm_sensors  # Hardware monitoring - useful on servers too
    upower      # Power management info - useful on servers too
    lf
    eza
    fd
    zoxide
    du-dust
    tree
    ripgrep
    neofetch
    imv
    openssl
    ipcalc
    dnsutils
    lsof
    libva-utils
    bc
    jq

    ffmpeg
    wget

    yt-dlp
    tree-sitter

    nh

    sshfs
  ];

  home.sessionVariables = {
    NH_FLAKE = "${config.home.homeDirectory}/nixconf";
  };
}
