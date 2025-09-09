{ config, lib, pkgs, ... }:
with lib;
let 
  cfg = config.myNixOS.wake-on-lan;
in {
  config = mkIf cfg.enable {

    # Create a systemd service that enables WOL on all wired interfaces
    systemd.services.wake-on-lan = {
      description = "Enable Wake-on-LAN on all wired interfaces";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "enable-wol" ''
          # Find all network interfaces (excluding loopback only)
          interfaces=$(${pkgs.iproute2}/bin/ip link show | \
                      ${pkgs.gnugrep}/bin/grep -E '^[0-9]+:' | \
                      ${pkgs.gnugrep}/bin/grep -v 'lo:' | \
                      ${pkgs.gawk}/bin/awk -F': ' '{print $2}' | \
                      ${pkgs.gawk}/bin/awk '{print $1}')
          
          for iface in $interfaces; do
            echo "Checking WOL support for interface: $iface"
            # Check if interface supports WOL
            if ${pkgs.ethtool}/bin/ethtool "$iface" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "Supports Wake-on:.*g"; then
              echo "Enabling Wake-on-LAN for interface: $iface"
              ${pkgs.ethtool}/bin/ethtool -s "$iface" wol g 2>/dev/null || echo "Failed to enable WOL for $iface"
            else
              echo "Interface $iface does not support Wake-on-LAN"
            fi
          done
        '';
      };
    };

    # Optional: Add a service to check current WOL status
    systemd.services.wake-on-lan-status = {
      description = "Display Wake-on-LAN status for all interfaces";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "check-wol-status" ''
          echo "=== Wake-on-LAN Status ==="
          interfaces=$(${pkgs.iproute2}/bin/ip link show | \
                      ${pkgs.gnugrep}/bin/grep -E '^[0-9]+:' | \
                      ${pkgs.gnugrep}/bin/grep -v 'lo:' | \
                      ${pkgs.gawk}/bin/awk -F': ' '{print $2}' | \
                      ${pkgs.gawk}/bin/awk '{print $1}')
          
          for iface in $interfaces; do
            echo "Interface: $iface"
            ${pkgs.ethtool}/bin/ethtool "$iface" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E "(Supports Wake-on|Wake-on)" || echo "  No WOL info available"
            echo ""
          done
        '';
      };
    };

    # Add ethtool and convenience script to system packages
    environment.systemPackages = [
      pkgs.ethtool
      (pkgs.writeShellScriptBin "wol-status" ''
        systemctl start wake-on-lan-status
        journalctl -u wake-on-lan-status --no-pager -n 50
      '')
    ];
  };
}