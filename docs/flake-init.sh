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
    echo "Error: Must be run from nixconf repository root"
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
    ZFS_IMPORT="    ./zfs-optimizations.nix"
else
    ZFS_IMPORT=""
fi

# Extract key info from original config
BOOT_CONFIG=$(grep -A 5 "boot.loader" "$CONFIG_DIR/configuration.nix" | grep -E "(systemd-boot|efi)" | head -3 || echo "")

# Detect system.stateVersion from installer config or use system's NixOS version
if grep -q "system.stateVersion.*=" "$CONFIG_DIR/configuration.nix"; then
    STATE_VERSION=$(grep "system.stateVersion.*=" "$CONFIG_DIR/configuration.nix" | head -1)
    # Extract just the version number for home.nix
    HOME_STATE_VERSION=$(echo "$STATE_VERSION" | grep -o '"[^"]*"' | tr -d '"')
else
    # Get current NixOS version as fallback
    NIXOS_VERSION=$(nixos-version | cut -d. -f1-2 || echo "25.05")
    STATE_VERSION="  system.stateVersion = \"$NIXOS_VERSION\";"
    HOME_STATE_VERSION="$NIXOS_VERSION"
fi

# Generate the new flake-based configuration.nix
cat > "hosts/$HOSTNAME/configuration.nix" << EOF
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
$ZFS_IMPORT
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  myNixOS = {
    bundles.general-desktop.enable = true;
    bundles.users = {
      enable = true;
      user = "$USERNAME";
    };
    # User configuration handled via home-manager userConfig
    home-users."$USERNAME".userConfig = ./home.nix;
  };

  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      configurationLimit = 17;
    };
    loader = {
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

  # User configuration provided by user bundle - no manual setup needed

  # Enable flakes and allow unfree
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  nixpkgs.config.allowUnfree = true;

  # Most packages provided by general-desktop bundle
  environment.systemPackages = with pkgs; [
    # Additional packages not in bundles
  ];

  environment.variables.EDITOR = "nvim";

  nix.optimise.automatic = true;
  nix.optimise.dates = [ "01:30" ];

  programs.appimage = {
    enable = true;
    binfmt = true;
  };



$STATE_VERSION
}
EOF

# Create basic home.nix
cat > "hosts/$HOSTNAME/home.nix" << EOF
{ config, lib, pkgs, inputs, ... }:

{
  home = {
    username = "$USERNAME";
    homeDirectory = "/home/$USERNAME";
    stateVersion = "$HOME_STATE_VERSION";
  };

  # Use $USERNAME's profile for consistent configuration
  myHomeManager = {
    profiles.$USERNAME.enable = true;
    
    # Add any host-specific customizations here
    # Example: bundles.desktop.enable = true;
    # Example: stylix.enable = true;
  };
  
  # Host-specific packages and configurations can go here
  home.packages = with pkgs; [
    # Additional packages specific to $HOSTNAME setup
  ];
}
EOF

# CRITICAL: Bootstrap SSH access for post-reboot system
# First, clean up any existing SSH bootstrap configs from previous runs
echo "Cleaning up any existing SSH bootstrap configuration..."
# Remove the SSH bootstrap block and any duplicate openssh configurations
sed -i '/# SSH Bootstrap - temporary until flake deploys/,/];/d' "$CONFIG_DIR/configuration.nix" 2>/dev/null || true
# Also remove any orphaned services.openssh.enable lines that might be duplicates
# Keep only the first occurrence if it exists
awk '/services.openssh.enable = true;/ && !seen {seen=1; print; next} /services.openssh.enable = true;/ {next} {print}' "$CONFIG_DIR/configuration.nix" > "$CONFIG_DIR/configuration.nix.tmp" && mv "$CONFIG_DIR/configuration.nix.tmp" "$CONFIG_DIR/configuration.nix"

# Now add the SSH config cleanly before the closing brace
echo "Adding SSH bootstrap configuration..."
sed -i '/^}$/i \
\
  # SSH Bootstrap - temporary until flake deploys (general bundle provides this)\
  services.openssh.enable = true;\
  users.users.root.openssh.authorizedKeys.keys = [\
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKaxtmB1X6IDyQGmtqUA148c4v/YBctuOBxLw6n0dsUY"\
  ];' "$CONFIG_DIR/configuration.nix"

# Apply SSH bootstrap configuration immediately
echo "Applying SSH bootstrap configuration..."
nixos-install --root /mnt --no-root-passwd --no-channel-copy

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

# Generate secure boot keys for lanzaboote
echo "Generating secure boot keys for lanzaboote..."
if [[ ! -f "/mnt/var/lib/sbctl/keys/db/db.key" ]]; then
    SBCTL=$(nix-build '<nixpkgs>' -A sbctl --no-out-link)/bin/sbctl
    $SBCTL create-keys
    mkdir -p /mnt/var/lib/sbctl
    cp -r /var/lib/sbctl/* /mnt/var/lib/sbctl/
    echo "✅ Secure boot keys created"
else
    echo "✅ Secure boot keys already exist"
fi
echo ""

# Get this system's IP dynamically
SYSTEM_IP=$(ip route get 9.9.9.9 2>/dev/null | awk '{print $7}' | head -1 || echo "INSTALLER_IP")


echo ""
echo "Host $HOSTNAME configuration created successfully!"
echo ""
echo "Next steps - run these commands from your development machine:"
echo ""
echo "# 1. Copy files and stage for commit:"
echo "scp -r root@$SYSTEM_IP:/root/nixconf/hosts/$HOSTNAME ~/nixconf/hosts/ && scp root@$SYSTEM_IP:/root/nixconf/flake.nix ~/nixconf/ && cd ~/nixconf && git add -A"
echo ""
echo "# 2. Unmount, export ZFS pool, reboot target, and clean up old SSH key:"
echo "ssh root@$SYSTEM_IP 'umount -R /mnt && zpool export rpool && reboot' && ssh-keygen -R $SYSTEM_IP"
echo ""
echo "# 3. Deploy configuration:"
echo "nixos-rebuild switch --flake ~/nixconf#$HOSTNAME --target-host root@$SYSTEM_IP --build-host $SYSTEM_IP --show-trace --option extra-experimental-features 'nix-command flakes'"
echo ""
echo "# 3b. (Optional) Monitor deployment in separate terminal:"
echo "ssh root@$SYSTEM_IP"
echo "systemd-inhibit nix-shell -p btop --run \"btop\""
echo ""
echo "# 4. Reboot to BIOS, clear Secure Boot keys, reboot to OS, then enroll:"
echo "ssh root@$SYSTEM_IP 'systemctl reboot --firmware-setup'"
echo "# (In BIOS: clear all Secure Boot keys to enter Setup Mode, save and reboot)"
echo "ssh root@$SYSTEM_IP 'sbctl enroll-keys'"
echo ""
echo "# 5. Re-enroll TPM2 (clearing Secure Boot keys wipes TPM):"
LUKS_DEVICE=\$(grep '^\s*device = ' \"~/nixconf/hosts/$HOSTNAME/zfs-optimizations.nix\" | grep -oE '/dev/[^\"]+' || echo \"/dev/nvme0n1p2\")
echo "ssh $SYSTEM_IP 'sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+2+7 $LUKS_DEVICE'"
echo ""
echo "# 6. Copy nixconf to user home and optimize hardware config:"
echo "scp -r ~/nixconf $SYSTEM_IP:~/ && ssh $SYSTEM_IP 'cd ~/nixconf && hardware-config-insert'"
echo ""
echo "# 7. Copy updated configuration back and commit everything:"
echo "scp -r $SYSTEM_IP:~/nixconf/hosts/$HOSTNAME ~/nixconf/hosts/"
echo "git commit -a -m \"feat($HOSTNAME): new host deployed and configured\""
echo ""
echo "Note: SSH access bootstrapped for post-reboot deployment"