---
status: solved
status-description: "Shared-package checks and Full GUI verification recorded"
---

# Installer configuration changes unnecessarily recompile Calamares
- Resolved: 2026-11-25

## Problem

Overriding the upstream package's `extraWrapperArgs` tied the compiled
Calamares derivation to variant-specific configuration and archive paths.
Settings-only changes therefore caused avoidable recompilation.

## Solution and verification

`c1a767f` reuses the unchanged Nixpkgs compiled package and adds a separate
wrapper supplying XDG paths and the configuration flag. Desktop launchers,
autostart and Polkit refer to that wrapper; the upstream Qt environment and
native modules remain intact.

Checks establish package sharing and wrapper/launcher/policy alignment for
every variant. Desktop built successfully; `9cf72b2` later records Full
autostart, Polkit desktop launch and graphical display confirmation.

## Evidence

- `c1a767f`, `9cf72b2`, `modules/installer/calamares-package.nix`.
