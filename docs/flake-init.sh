#!/usr/bin/env bash
# Initialize a new host in the flake from nixos-install generated configs
# Usage: ./flake-init.sh <hostname>

set -euo pipefail

HOSTNAME="${1:-}"
USERNAME="${2:-emet}"

if [[ -z "$HOSTNAME" ]]; then
    echo "Usage: $0 <hostname> [username]"
    echo "Example: $0 hearth"
    echo "Example: $0 hearth joelle"
    echo ""
    echo "This script:"
    echo "  1. Creates hosts/<hostname>/ directory structure"
    echo "  2. Copies and transforms nixos-install generated configs"
    echo "  3. Updates flake.nix with the new host"
    echo "  4. Defaults to username 'emet' if not specified"
    exit 1
fi

echo "Initializing host: $HOSTNAME (user: $USERNAME)"

# Check if we're in the nixconf repository
if [[ ! -f "flake.nix" ]]; then
    echo "❌ Must be run from nixconf repository root"
    exit 1
fi

# Check for fresh nixos-install environment
if [[ -f "/mnt/etc/nixos/configuration.nix" && -f "/mnt/etc/nixos/hardware-configuration.nix" ]]; then
    CONFIG_DIR="/mnt/etc/nixos"
else
    echo "No fresh nixos-install found - requires /mnt/etc/nixos/ with generated configs"
    exit 1
fi

# Check if host already exists and handle re-initialization
if [[ -d "hosts/$HOSTNAME" ]]; then
    read -p "Host '$HOSTNAME' exists. Re-initialize? (y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
    rm -rf "hosts/$HOSTNAME"
fi

# Create host directory structure
mkdir -p "hosts/$HOSTNAME"

# Copy configs and prepare
cp "$CONFIG_DIR/hardware-configuration.nix" "hosts/$HOSTNAME/"
if [[ -f "$CONFIG_DIR/zfs-optimizations.nix" ]]; then
    cp "$CONFIG_DIR/zfs-optimizations.nix" "hosts/$HOSTNAME/"
    ZFS_IMPORT="      ./zfs-optimizations.nix"
else
    ZFS_IMPORT=""
fi

# Extract key info from original config
BOOT_CONFIG=$(grep -A 5 "boot.loader" "$CONFIG_DIR/configuration.nix" | grep -E "(systemd-boot|efi)" | head -3 || echo "")

# Detect system.stateVersion from installer config or use system's NixOS version
if grep -q "system.stateVersion" "$CONFIG_DIR/configuration.nix"; then
    STATE_VERSION=$(grep "system.stateVersion" "$CONFIG_DIR/configuration.nix" | head -1)
else
    # Get current NixOS version as fallback
    NIXOS_VERSION=$(nixos-version | cut -d. -f1-2 || echo "25.05")
    STATE_VERSION="  system.stateVersion = \"$NIXOS_VERSION\";"
fi

# Generate the new flake-based configuration.nix
cat > "hosts/$HOSTNAME/configuration.nix" << EOF
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
$ZFS_IMPORT
  ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users.enable = true;
    sysadmin.enable = true;
    sysadmin.allowedActions = "anarchy";  # No prompts for curated admin commands
    greetd.enable = true;  # Display manager for Hyprland
    kanshi.enable = true;  # Display management
    tpm2.enable = true;  # TPM2 support for LUKS auto-unlock
    stylix = {
      enable = true;
      theme = "terracotta-atomic";  # $HOSTNAME gets the terracotta/atomic theme
    };
    home-users = {
      "$USERNAME" = {
        # Profile automatically selected as profiles/$USERNAME.nix
        userSettings = {
          extraGroups = [ "incus-admin" "libvirtd" "networkmanager" "wheel" "audio" "avahi" "video" ];
        };
        # Host-specific home configuration
        userConfig = ./home.nix;
      };
    };
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };

  networking = {
    hostName = "$HOSTNAME";
    networkmanager.enable = true;
  };

  system.autoUpgrade.enable = false;

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
    ];
  };

  users.users.$USERNAME = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY jm-ecc"
    ];
    packages = with pkgs; [
      appimage-run
      (azure-cli.overrideAttrs (oldAttrs: {
        doInstallCheck = false;
      }))
      azure-cli-extensions.azure-firewall
      kitty # Terminal emulator, recommended for Hyprland
      microsoft-edge
      powershell
      remmina
      tree
      yazi
    ];
  };

  # Enable flakes and allow unfree
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    acpi
    brightnessctl
    colorls
    dunst
    fastfetch
    flatpak
    font-awesome
    freerdp
    fwupd
    geany
    glxinfo
    hyprland
    kitty
    libnotify
    mesa-demos
    neovide
    networkmanagerapplet
    nh
    nix-output-monitor
    ntfs3g
    openconnect
    pavucontrol
    qbittorrent
    rofi-wayland
    swww
    tmux
    unzip
    vim
    vulkan-tools
    waybar
    wayland
    wget
    wl-clipboard
    xorg.xorgserver
    xwayland
    zip
  ];

  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.fwupd.enable = true;
  services.openssh.enable = true;
  services.protonmail-bridge.enable = false;
  services.teamviewer.enable = false;

$STATE_VERSION
}
EOF

# Create basic home.nix
cat > "hosts/$HOSTNAME/home.nix" << EOF
{ config, lib, pkgs, inputs, ... }:

{
  myHomeManager = {
    bundles.general.enable = true;
    bundles.databender.enable = true;  # Azure/PowerShell work tools
    
    # $HOSTNAME-specific customizations
    # Terracotta/atomic theme preferences will be handled by stylix
  };
  
  # Host-specific packages and configurations can go here
  home.packages = with pkgs; [
    # Additional packages specific to $HOSTNAME setup
  ];
}
EOF

# CRITICAL: Bootstrap SSH access for post-reboot system
# Insert SSH config before the closing brace
sed -i '/^}$/i \
\
  # SSH Bootstrap - ensures access after reboot before flake deployment\
  services.openssh.enable = true;\
  users.users.root.openssh.authorizedKeys.keys = [\
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY"\
  ];' "$CONFIG_DIR/configuration.nix"

# Backup flake.nix before modifications
cp flake.nix flake.nix.bak

# Update flake.nix (only host sections)
if ! grep -q "$HOSTNAME = mkSystem" flake.nix; then
    awk -v host="$HOSTNAME" '
    /NixOS Configurations/ { print; getline; print; print "        " host " = mkSystem ./hosts/" host "/configuration.nix;"; next }
    { print }
    ' flake.nix > flake.nix.tmp && mv flake.nix.tmp flake.nix
fi

if ! grep -q "\"$USERNAME@$HOSTNAME\"" flake.nix; then
    awk -v user="$USERNAME" -v host="$HOSTNAME" '
    /Home Configurations/ { print; getline; print; print "        \"" user "@" host "\" = mkHome \"x86_64-linux\" ./hosts/" host "/home.nix;"; next }
    { print }
    ' flake.nix > flake.nix.tmp && mv flake.nix.tmp flake.nix
fi

echo "Host initialization complete!"
echo ""
# Get this system's IP dynamically
SYSTEM_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1 || echo "INSTALLER_IP")

echo "Next steps:"
echo "1. **BACKUP FLAKE.NX** (from your deployment machine):"
echo "   cp ~/nixconf/flake.nix ~/nixconf/flake.nix.bak"
echo ""
echo "2. Capture files (from your deployment machine):"
echo "   scp -r root@$SYSTEM_IP:/tmp/nixconf/hosts/$HOSTNAME ~/nixconf/hosts/ && scp root@$SYSTEM_IP:/tmp/nixconf/flake.nix ~/nixconf/flake.nix && cd ~/nixconf && git add -A"
echo ""
echo "3. Reboot this system, then deploy remotely:"
echo "   systemd-inhibit --what=sleep,shutdown,idle --who=nixos-rebuild --why='Remote deployment' nixos-rebuild switch --flake ~/nixconf#$HOSTNAME --target-host root@$SYSTEM_IP --show-trace"
echo ""
echo "4. ONLY commit after successful deploy:"
echo "   cd ~/nixconf && git add hosts/$HOSTNAME/ flake.nix && git commit -m 'feat($HOSTNAME): add new host'"
echo ""
echo "Note: SSH access bootstrapped for post-reboot deployment"