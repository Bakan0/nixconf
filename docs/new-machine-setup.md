# New Machine Setup

## Initial switch command (before experimental features are enabled):
```bash
sudo nixos-rebuild switch --flake ~/nixconf#HOSTNAME --show-trace --option extra-experimental-features "nix-command flakes"

