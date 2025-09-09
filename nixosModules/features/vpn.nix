{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.vpn;
in {
  config = mkIf cfg.enable {
    # Eddie requires dotnet packages
    nixpkgs.config.permittedInsecurePackages = mkIf (cfg.eddie or true) [
      "dotnet-sdk-6.0.428"
      "dotnet-runtime-6.0.36"
    ];
    
    # WireGuard support - enabled by default
    networking.wireguard.enable = mkDefault (cfg.wireguard or true);
    
    # L2TP/IPSec support - disabled by default
    services.xl2tpd.enable = mkIf (cfg.l2tp or false) true;
    services.strongswan = mkIf (cfg.l2tp or false) {
      enable = true;
      secrets = [];
    };
    
    # VPN packages
    environment.systemPackages = mkMerge [
      (mkIf (cfg.eddie or true) [ pkgs.eddie ])
      (mkIf (cfg.wireguard or true) [ pkgs.wireguard-tools ])
      (mkIf (cfg.l2tp or false) [ 
        pkgs.xl2tpd 
        pkgs.strongswan 
        pkgs.networkmanager-l2tp
      ])
      (mkIf (cfg.openvpn or true) [ 
        pkgs.openvpn 
        pkgs.networkmanager-openvpn
      ])
    ];
    
    # Common VPN dependencies
    networking.networkmanager.enable = mkDefault true;
  };
}