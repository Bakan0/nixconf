{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users = {
      enable = true;
      user = "joelle";  # Joelle's profile with GNOME, packages, SSH keys
    };
    sddm.enable = false;
    hyprland.enable = false;
    tpm2.enable = true;
    virtualisation.enable = false;
    wake-on-lan.enable = true;
    home-users = {
      "joelle" = {
        userConfig = ./home.nix;  # Use host-specific home config
        userSettings = {
          extraGroups = [ "networkmanager" "wheel" "audio" "video" ];
        };
      };
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "mariposa";
    networkmanager.enable = true;
  };


  # Set your time zone.
  time.timeZone = "America/Chicago";


  nixpkgs.config.allowUnfree = true;


   environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    colorls
    curl
    dunst
    fastfetch
    flatpak
    font-awesome
    freerdp
    git
    hyprland
    kitty
    libnotify
    neovide
    networkmanagerapplet
    nh
    nix-output-monitor
    ntfs3g
    openconnect
    pavucontrol
    rofi-wayland
    swww
    tmux
    unzip
    vim
    waybar
    wayland
    wget
    wl-clipboard
    xorg.xorgserver
    xwayland
    zip
   ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

