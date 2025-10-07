{ config, lib, pkgs, ... }:
let
  cfg = config.myNixOS.zerotierone;
  # Look for networks file in host directory (gitignored)
  networksFile = toString ../.. + "/hosts/${config.networking.hostName}/zerotier-networks.nix";
in {
  options.myNixOS.zerotierone = {
    clientMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Client mode for on-demand ZeroTier usage (laptops).
        Service installed but won't auto-start on boot.
        Start manually: sudo systemctl start zerotierone
        Default (false): Server mode - auto-starts on boot
      '';
    };
  };

  # Enable ZeroTier service
  services.zerotierone = {
    enable = true;
    # Load networks from gitignored file if it exists
    joinNetworks =
      if builtins.pathExists networksFile
      then import networksFile
      else [];
  };

  # Client mode: prevent auto-start on boot
  # mkForce needed here to override upstream nixpkgs hardcoded wantedBy
  systemd.services.zerotierone.wantedBy = lib.mkIf cfg.clientMode (lib.mkForce []);
}
