# Converting Existing NixOS to Flake

For machines that already have NixOS installed but need to convert to this flake configuration:

## Initial switch command (before experimental features are enabled):
```bash
sudo nixos-rebuild switch --flake ~/nixconf#HOSTNAME --show-trace --option extra-experimental-features "nix-command flakes"

