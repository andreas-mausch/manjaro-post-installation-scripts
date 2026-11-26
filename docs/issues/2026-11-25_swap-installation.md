# Calamares swap choices are not integrated with generated NixOS hardware settings

- Status: Open; no-swap restriction retained as a safeguard
- Recorded: 2026-11-25

## Problem

`nixos-generate-config` detects only active swap partitions, not swap files.
Calamares creates swap files in its fstab module, which this installer does
not run. Exposing swap choices without integration would not establish a
working declarative target configuration or encrypted swap after reboot.

## Current behavior and remaining work

The installer permits no swap and provides no hibernation configuration.
Implement and test target-device mapping and encrypted swap after reboot
before enabling swap choices. Do not remove the restriction based only on
native UI availability.

## Evidence

- `83db41d`, `d8cd297`, current `TODO.md`.
