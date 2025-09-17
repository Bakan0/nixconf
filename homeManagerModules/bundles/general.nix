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
    # Tools moved to system for server/root access: nh, jq, dnsutils, eza, fd, htop, lm_sensors, tree, ripgrep, openssl, lsof, unzip, fwupd, bc, neofetch, file, zip
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
  ];

  home.sessionVariables = {
    NH_FLAKE = "${config.home.homeDirectory}/nixconf";
  };
}
