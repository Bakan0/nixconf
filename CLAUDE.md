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

**Primary deployment (rebuilds BOTH system AND home-manager):**
```fish
nh os switch ~/nixconf/. -- --show-trace
```

**⚠️ CRITICAL: Always stage file changes before rebuilding:**
```fish
git add -A  # Required before any rebuild if files created/renamed/deleted
nh os switch ~/nixconf/. -- --show-trace
```

**Remote deployment (build locally, deploy to another host):**
```fish
sudo nixos-rebuild switch --flake ~/nixconf#HOSTNAME --target-host root@HOST_IP --show-trace
```

**Initial system build (new machines only):**
```fish
sudo nixos-rebuild switch --flake ~/nixconf#HOSTNAME --show-trace --option extra-experimental-features "nix-command flakes"
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
- **Shell**: Fish for interactive use (scripts/configs use appropriate system defaults)

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

**❌ NEVER commit broken builds** - Always test major changes before committing
**❌ NEVER duplicate configuration attributes** (e.g., multiple `home.packages` in same module)  
**❌ NEVER EVER add AI-generated commit message footers like "Generated with Claude Code" or "Co-Authored-By: Claude" 
**❌ NEVER write long commit messages - keep them concise (1-4 lines max using conventional commits)**
**❌ NEVER use `lib.mkForce` (indicates poor design in 99% of cases)
**❌ NEVER use `nh home switch` (breaks Stylix theming)

**✅ Architecture Patterns:**
- Use `myLib/default.nix` `extendModules` function - auto-creates enable options for all features
- Desktop-specific config belongs in bundles, not profiles
- Remember: `nh os switch` rebuilds BOTH system AND home-manager
- Always `git add -A` before rebuilds if files were created/renamed/deleted
- Use proper NixOS patterns, avoid hardcoded paths
- Follow Conventional Commits specification for all messages

### Git Commit Standards

**Conventional Commits (MANDATORY):**
- **Format:** `<type>[optional scope]: <description>`
- **Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`
- **Scopes:** `hyprland`, `stylix`, `home`, `system`, `flake`, `modules`, `hosts`
- **Breaking changes:** Use `!` after type/scope

**NixOS-Specific Examples:**
```
feat(hyprland): add new keybinding configuration
fix(stylix): resolve theme loading for terminal
refactor(modules): restructure nixosModules organization  
chore(flake): update input dependencies
docs: update module development guidelines
```