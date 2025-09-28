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
  myHomeManager.foot.enable = lib.mkDefault true;
  myHomeManager.fish.enable = lib.mkDefault true;  # Fish works for everyone - those who don't use terminal won't notice

  myHomeManager.stylix.enable = lib.mkDefault true;

  # myHomeManager.bottom.enable = lib.mkDefault true;

  programs.home-manager.enable = true;

  programs.lazygit.enable = true;
  programs.bat.enable = true;

  # SSH agent service for persistent key storage across sessions
  services.ssh-agent.enable = true;

  home.packages = with pkgs; [
    # Tools moved to system for server/root access: nh, jq, dnsutils, eza, fd, htop, lm_sensors, tree, ripgrep, openssl, lsof, unzip, fwupd, bc, neofetch, file, zip
    # Keyring/secret management - needed by many desktop apps (Nextcloud, browsers, etc)
    gnome-keyring
    libsecret
    libgnome-keyring
    nil
    pistol
    p7zip
    libqalculate
    imagemagick
    killall
    pamixer
    alsa-utils
    rofi-bluetooth
    fzf
    upower
    lf
    zoxide
    du-dust
    imv
    ipcalc
    libva-utils
    ffmpeg
    yt-dlp
    tree-sitter
    sshfs
    astroterm
    pastel
  ];

  home.sessionVariables = {
    NH_FLAKE = "${config.home.homeDirectory}/nixconf";
  };
}
