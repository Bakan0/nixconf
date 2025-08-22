# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## NixOS Configuration Repository

This repository contains a multi-host NixOS configuration using Nix flakes and Home Manager. It follows a modular architecture with custom library functions for code reuse across different systems.

### Key Architecture Components

**Flake Structure:**
- `flake.nix` - Main entry point defining inputs, outputs, and system configurations
- `myLib/default.nix` - Custom library with helper functions (`mkSystem`, `mkHome`, `extendModules`)
- `nixosModules/` - System-level modules with automatic enable options
- `homeManagerModules/` - User-level modules with automatic enable options
- `hosts/` - Per-machine configurations

**Module System:**
The repository uses a custom module extension system where:
- Features in `nixosModules/features/` automatically get `myNixOS.{name}.enable` options
- Features in `homeManagerModules/features/` automatically get `myHomeManager.{name}.enable` options
- Bundles group related features together
- Hardware modules provide hardware-specific configurations

**Host Configuration:**
Each host directory contains:
- `configuration.nix` - NixOS system configuration
- `home.nix` - Home Manager user configuration
- `hardware-configuration.nix` - Hardware-specific settings

### Development Commands

**Primary deployment method:**
```fish
nh os switch ~/nixconf/. -- --show-trace
```

**Initial system build (for new machines):**
```fish
sudo nixos-rebuild switch --flake ~/nixconf#HOSTNAME --show-trace --option extra-experimental-features "nix-command flakes"
```

**Alternative rebuild commands:**
```fish
# Rebuild current system
sudo nixos-rebuild switch --flake .

# Rebuild specific host  
sudo nixos-rebuild switch --flake .#HOSTNAME

# Update flake inputs and rebuild
nix flake update && sudo nixos-rebuild switch --flake .
```

**Testing changes:**
```fish
# Dry run
sudo nixos-rebuild dry-run --flake .
```

**Development shell:**
```fish
nix develop  # Provides nh, nix, home-manager, git, neovim
```

**⚠️ CRITICAL:** Never use `nh home switch` - breaks Stylix theming

**Available hosts:** acc01ade, mariposa, petalouda, nighthawk, tyr, dazzle, hermit

### Module Development

**Standard module pattern:**
```nix
# nixosModules/features/example/default.nix
{ config, lib, pkgs, ... }:
with lib;
let cfg = config.myNixOS.example;
in {
  config = mkIf cfg.enable {
    # system-wide configuration
  };
}
```

**Adding new features:**
1. Create module in `nixosModules/features/` or `homeManagerModules/features/`
2. Module automatically gets enable option via `extendModules` function
3. Use in host config: `myNixOS.{moduleName}.enable = true;`

**Adding bundles:**
1. Create in respective `bundles/` directory
2. Gets enable option: `myNixOS.bundles.{name}.enable = true;`

**⚠️ IMPORTANT:** Never suggest duplicate enable options - `extendModules` handles this automatically

### System Environment

**Core Technologies:**
- **NixOS**: unstable branch
- **Window Manager**: Hyprland (Wayland) - ensure all configs are Wayland-compatible
- **Theming**: Stylix with base16 colors (system-wide theming)
- **Shell**: Fish (use fish syntax exclusively, never bash/zsh)

**Key Features:**
- **Impermanence**: System designed for ephemeral root filesystem
- **ZFS**: Advanced filesystem features and optimizations  
- **Multi-user support**: Different users can have separate home configurations on same host

### Configuration Guidelines

**Hierarchy Preference:**
- Prefer system-wide over user-specific configurations
- Use `myNixOS` namespace for system modules
- Respect existing modular patterns

**Shell Operations:**
```fish
# Copy file contents to clipboard
wl-copy < path/to/file

# View and copy file
bat /path/to/file | wl-copy
```

### Common Operations

**Add new host:**
1. Create directory in `hosts/`
2. Add configuration files
3. Add to `nixosConfigurations` and `homeConfigurations` in `flake.nix`

### Critical Rules

**❌ FORBIDDEN:**
- Using bash/zsh syntax (always use fish)
- Breaking modular structure
- Ignoring Stylix theming compatibility
- Home-manager user configs for system-wide features
- Adding "Generated with Claude Code" or "Co-Authored-By: Claude" to commit messages

**✅ REQUIRED:**
- Ensure Hyprland/Wayland compatibility for all GUI applications
- Build upon existing solutions in conversation context
- Ask clarifying questions before suggesting code changes
- Keep commit messages clean and focused on actual changes
- Treat collaboration as editing/debugging assistance, not co-authoring
- Always run `git add -A` before committing, especially when creating new files
- Remember that `nh os switch` and `sudo` commands cannot be run by Claude