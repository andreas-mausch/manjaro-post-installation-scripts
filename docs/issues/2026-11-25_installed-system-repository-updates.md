---
status: open
status-description: "Desktop VM update/fallback/rollback verified; migration and remaining coverage pending"
---

# Repository updates require host files in the checkout and careful source selection

## Problem

The installed Flake is an archived copy, not an automatically updated checkout.
`nix flake update` updates inputs, not repository modules. Current targets load
hardware and identity through paths relative to the Flake. A checkout without
the PC's files falls back to reference filesystems and user settings. Git Flake
source filtering also omits ignored/untracked host files.

Rebuilding from a checkout does not update `/etc/nixos`; later rebuilding from
that older source can reactivate the old project version.

## Current workaround and remaining work

New ISO builds now generate a real local system Flake that imports the selected
profile from `my-os-setup` with `flake = false`, while keeping host files under
`/etc/nixos`. An explicitly supplied temporary Git folder is cloned locally into
`/etc/nixos/my-os-setup`, without fetching during installation. The initial lock
uses retained ISO sources; later explicit updates use GitHub or a local override.
See [administration](../administration.md) for the current workflow.

Offline evaluation of generated Desktop, AI and Full Flakes has been tested
with local hardware/identity settings and hostname changes. A local source
override persists for rebuilds while ordinary updates return to GitHub.
Desktop VM update/fallback/rollback evidence is recorded below. Migration from
archived installations and remaining coverage are still open. The older
workaround below describes the pre-migration situation only.

The README documents copying the existing PC-specific files after checking
for local work, then rebuilding explicitly from a `path:` Flake. Keep the
password hash outside the repository and use the same source for later updates.
This checkout workflow is not yet VM-validated.

`48b9e5d` adds editable local configuration and hostname aliases; `67889f8`
isolates repository composition from reusable modules. Neither implements the
planned workflow that keeps PC data under `/etc/nixos` and consumes reusable
modules as a pinned input, including local checkout support without `--impure`.
That work remains in `TODO.md`.

## Evidence

### Desktop QEMU/KVM VM, user-confirmed on 2026-11-27

- The user booted the installed Desktop system and successfully ran
  `sudo nixos-rebuild switch` without network access.
- The bundled `/etc/nixos/my-os-setup` checkout was clean on branch `nixos`,
  tracked `origin/nixos`, and had the expected GitHub fetch/push remote.
- A targeted `nix flake update my-os-setup --flake path:/etc/nixos
  --override-input my-os-setup path:/etc/nixos/my-os-setup` succeeded offline.
  The subsequent short rebuild and reboot succeeded.
- After enabling networking and pushing the project, the user ran
  `nix flake update --flake path:/etc/nixos`. The lock changed from the local
  checkout to GitHub commit `e42bf9186e4d89659a78783d22e7550690fdfe15`.
  Nixpkgs changed from a retained path to GitHub but kept revision
  `2786a2a72088ecf32aea5b3ec52099e6a7cff78f` (the ISO's revision).
- The online rebuild and reboot succeeded. A screenshot of the installed lock
  confirmed `flake = false`, the expected owner/repository and project revision.
- The user confirmed rollback/reboot and reactivation/reboot succeeded after
  following the supplied commands. No lock backup was made; generation rollback
  does not restore the lockfile.

Screenshots document update and activation outputs; reboot and rollback outcomes
are user reports. This evidence covers this Desktop VM, not migration, SSH
access (the ISO carried no authorized keys), AI/Full updates, changed dependency
revisions, explicit host-setting preservation assertions or Bosgame hardware.

- `67ef4cd`, `48b9e5d`, `67889f8`, current README and TODO.
