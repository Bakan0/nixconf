{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.asus;
in {
  options.myNixOS.asus = {
    enableGpuSwitching = mkOption {
      type = types.bool;
      default = true;
      description = "Enable SuperGFX GPU switching";
    };
  };

  config = mkIf cfg.enable {
    boot.kernelModules = [ "asus-wmi-sensors" "asus-nb-wmi" ];

    # SuperGFXD service:
    systemd.services.supergfxd = mkIf cfg.enableGpuSwitching {
      description = "SUPERGFX";
      unitConfig = {
        StartLimitInterval = 200;
        StartLimitBurst = 2;
        Before = "graphical.target multi-user.target display-manager.service";
        After = "zfs-import.target zfs.target plymouth-quit.service";
        Wants = "zfs.target";
      };
      serviceConfig = {
        Environment = [
          "IS_SERVICE=1"
          "RUST_LOG=debug"
        ];
        ExecStart = "${pkgs.supergfxctl}/bin/supergfxd";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
        Restart = "always";
        RestartSec = "1";
        Type = "dbus";
        BusName = "org.supergfxctl.Daemon";
      };
      wantedBy = [ "getty.target" ];
      enable = true;
    };

    # All the AMD GPU monitoring tools:
    environment.systemPackages = with pkgs; [
      asusctl
      supergfxctl
      rocmPackages.rocminfo    # ROCm system info
      rocmPackages.rocm-smi    # ROCm GPU monitoring
      radeontop               # Simple AMD GPU monitor
      amdgpu_top              # Advanced AMD GPU monitor
    ];
  };
}
