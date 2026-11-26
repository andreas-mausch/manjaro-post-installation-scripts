---
status: open
status-description: "Manual partitioning intentionally disabled; safe manual LUKS support unverified"
---

# Upstream Calamares patch prevents manual LUKS filesystem selection

## Problem and current decision

The pinned Nixpkgs Calamares package includes `dont-allow-manual-luks.patch`,
which removes LUKS/LUKS2 from manual filesystem dialogs. Removing this patch
without testing would not establish safe manual encryption support.

`83db41d` retains the patch and disables manual partitioning. Automatic LUKS2
partitioning remains supported; later encrypted UEFI VM installation succeeded.
The configured default is Btrfs without additional subvolumes. An empty
Calamares subvolume list would activate its default layout, so the integration
explicitly requests the top-level filesystem instead.

## Remaining work

Review available native settings and test supported manual layouts before
exposing them. The Calamares UI audit remains in `TODO.md`. Current installation
erases the selected whole drive; this issue is not a workaround for preserving
other operating systems or data.

## Evidence

- `83db41d`, current README and `TODO.md`.
