# Adapter rejects encryption and password choices after native validation

- Status: Fixed; encrypted Full installation confirmed, other paths unit-tested
- Recorded: 2026-11-25
- Resolved: 2026-11-25

## Problem

The adapter required encryption, imposed a late twelve-character LUKS
policy and duplicated user-password validation after the native UI.
It also required Btrfs despite deployment primarily needing valid root and
EFI mounts. Late rejection could occur after disk partitioning.

## Solution and verification

`d8cd297` permits encrypted or unencrypted installation, delegates password
checks to Calamares and removes the adapter's Btrfs restriction. Btrfs stays
the configured default. Tests cover optional encryption, other root
filesystems and native validation. Later Full VM installation confirms the
encrypted path, not every filesystem or unencrypted configuration.

The [swap restriction](../2026-11-25_swap-installation.md) remains intentional.

## Evidence

- `d8cd297`, historical README and `7eb2955`.
