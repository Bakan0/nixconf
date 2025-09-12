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

  # Script to create a properly configured Windows VM
  windowsVMScript = pkgs.writeShellScriptBin "create-windows-vm" ''
    set -euo pipefail
    
    VM_NAME="$1"
    ISO_PATH="$2"
    DISK_SIZE="''${3:-60G}"
    RAM_SIZE="''${4:-8192}"
    
    if [ $# -lt 2 ]; then
      echo "Usage: create-windows-vm <vm-name> <iso-path> [disk-size] [ram-mb]"
      echo "Example: create-windows-vm win11 ~/Downloads/Windows11.iso 80G 12288"
      exit 1
    fi
    
    if [ ! -f "$ISO_PATH" ]; then
      echo "Error: ISO file not found at $ISO_PATH"
      exit 1
    fi
    
    echo "Creating Windows VM: $VM_NAME"
    echo "ISO: $ISO_PATH"
    echo "Disk: $DISK_SIZE, RAM: $RAM_SIZE MB"
    echo
    
    # Create the VM with proper UEFI and networking
    ${pkgs.virt-manager}/bin/virt-install \
      --name="$VM_NAME" \
      --ram=$RAM_SIZE \
      --vcpus=4 \
      --cpu=host \
      --disk=path=/var/lib/libvirt/images/"$VM_NAME".qcow2,size=''${DISK_SIZE%G},format=qcow2,bus=virtio \
      --cdrom="$ISO_PATH" \
      --disk=path=${pkgs.virtio-win}/share/virtio-win/virtio-win.iso,device=cdrom \
      --os-variant=win11 \
      --network=network=default,model=virtio \
      --graphics=spice \
      --video=qxl \
      --sound=ich9 \
      --boot=uefi \
      --machine=q35 \
      --features=acpi,apic,hyperv_relaxed,hyperv_vapic,hyperv_spinlocks_state=on,hyperv_spinlocks_retries=8191 \
      --clock=offset=localtime,rtc_tickpolicy=catchup \
      --pm=suspend_to_mem.enabled=off,suspend_to_disk.enabled=off \
      --noautoconsole
      
    echo
    echo "✅ VM '$VM_NAME' created successfully!"
    echo "📁 Disk image: /var/lib/libvirt/images/$VM_NAME.qcow2"
    echo "🚀 Starting virt-manager to complete Windows installation..."
    echo
    echo "Windows Installation Tips:"
    echo "1. When prompted for drivers, browse to the VirtIO CD (usually D:)"
    echo "2. Install storage driver from: viostor/w11/amd64/"
    echo "3. Install network driver from: NetKVM/w11/amd64/"
    echo "4. After Windows install, install all VirtIO drivers from the CD"
    echo
    
    # Launch virt-manager 
    ${pkgs.virt-manager}/bin/virt-manager --connect qemu:///system --show-domain-console="$VM_NAME" &
  '';
in {
  options.myNixOS.virtualisation = {
    # The enable option is already handled by your myLib/default.nix
    username = mkOption {
      type = types.str;
      default = "emet";  # Default username
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

    # Ensure all necessary packages are installed
    environment.systemPackages = with pkgs; [
      # Include our auto-connect script and desktop file
      autoConnectScript
      autoConnectDesktopFile

      # Windows VM creation script
      windowsVMScript

      # Include the original virt-manager and other packages
      virt-manager
      virt-viewer
      qemu
      qemu-utils
      libvirt
      spice spice-gtk spice-protocol
      virtio-win
      swtpm
      virtiofsd
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

    # Ensure socket permissions are correct and create images directory
    systemd.tmpfiles.rules = [
      "d /run/libvirt 0755 root root -"
      "z /run/libvirt/libvirt-sock 0666 root root -"
      "d /var/lib/libvirt/images 0755 root root -"
    ];

    # Add a shell alias for convenience
    environment.shellAliases = {
      "vm" = "virt-manager-connect";
    };
    
    # Create default network if it doesn't exist
    systemd.services.libvirt-default-network = {
      description = "Create default libvirt network";
      after = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "setup-default-network" ''
          # Check if default network exists
          if ! ${pkgs.libvirt}/bin/virsh net-list --all | grep -q default; then
            # Create default network
            cat > /tmp/default-network.xml << 'EOF'
<network>
  <name>default</name>
  <uuid>$(${pkgs.util-linux}/bin/uuidgen)</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:12:34:56'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
            ${pkgs.libvirt}/bin/virsh net-define /tmp/default-network.xml
            rm /tmp/default-network.xml
          fi
          
          # Start and autostart the default network
          ${pkgs.libvirt}/bin/virsh net-start default 2>/dev/null || true
          ${pkgs.libvirt}/bin/virsh net-autostart default
        ''}";
      };
    };
  };
}
