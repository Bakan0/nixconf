# nixosModules/features/virtualisation/default.nix
{ config, lib, pkgs, ... }: 

with lib;
let
  cfg = config.myNixOS.virtualisation;

  # Create a simple shell script that launches virt-manager with auto-connect
  autoConnectScript = pkgs.writeShellScriptBin "virt-manager-connect" ''
    exec ${pkgs.virt-manager}/bin/virt-manager --connect qemu:///system "$@"
  '';

  # Create a desktop entry for our auto-connect script
  autoConnectDesktopFile = pkgs.writeTextFile {
    name = "virt-manager-connect.desktop";
    destination = "/share/applications/virt-manager-connect.desktop";
    text = ''
      [Desktop Entry]
      Name=VM Manager (Auto-Connect)
      Comment=Manage virtual machines (auto-connects to system)
      Exec=${autoConnectScript}/bin/virt-manager-connect
      Terminal=false
      Type=Application
      Icon=virt-manager
      Categories=System;
      Keywords=virtualization;
    '';
  };
in {
  options.myNixOS.virtualisation = {
    username = mkOption {
      type = types.str;
      default = "emet";
      description = "Username for libvirtd access";
    };
  };

  config = mkIf cfg.enable {
    # Enable libvirtd with explicit QEMU configuration
    virtualisation = {
      libvirtd = {
        enable = true;
        onBoot = "start";
        qemu = {
          package = pkgs.qemu;
          runAsRoot = true;
          swtpm.enable = true;
          ovmf = {
            enable = true;
            packages = [pkgs.OVMFFull.fd];
          };
        };
      };
      spiceUSBRedirection.enable = true;
    };

    # Ensure all necessary packages are installed for Windows VMs
    environment.systemPackages = with pkgs; [
      # Include our auto-connect script and desktop file
      autoConnectScript
      autoConnectDesktopFile

      # Core virtualization packages
      virt-manager
      virt-viewer
      qemu
      qemu-utils
      libvirt
      
      # SPICE for Windows VM graphics and USB redirection
      spice 
      spice-gtk 
      spice-protocol
      
      # VirtIO Windows drivers for optimal performance
      virtio-win
      
      # TPM support for Windows 11
      swtpm
      
      # VirtIO filesystem daemon for folder sharing
      virtiofsd
      
      # Hardware utilities for PCI/USB passthrough
      pciutils
      usbutils
    ];

    # Add environment variable for VirtIO drivers
    environment.variables.VIRTIO_WIN_ISO = "${pkgs.virtio-win}/share/virtio-win/virtio-win.iso";

    # Enable dconf - required for saving VM settings
    programs.dconf.enable = true;

    # Make sure users in the libvirtd group have access
    users.groups.libvirtd.members = [ cfg.username ];
    users.groups.kvm.members = [ cfg.username ];

    # Create a polkit rule to allow the user to manage VMs without password
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.libvirt.unix.manage" &&
            subject.user == "${cfg.username}") {
          return polkit.Result.YES;
        }
      });
    '';

    # Ensure socket permissions are correct
    systemd.tmpfiles.rules = [
      "d /run/libvirt 0755 root root -"
      "z /run/libvirt/libvirt-sock 0666 root root -"
    ];

    # Add a shell alias for convenience
    environment.shellAliases = {
      "vm" = "virt-manager-connect";
    };
  };
}

