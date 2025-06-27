{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.myNixOS.tpm2;
in {
  config = mkIf cfg.enable {
    # TPM2 tools
    environment.systemPackages = with pkgs; [
      tpm2-tools
      tpm2-tss
    ];

    # TPM2 support
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    # CRITICAL: Enable systemd in initrd for TPM2 LUKS
    boot.initrd.systemd.enable = true;
  };
}

