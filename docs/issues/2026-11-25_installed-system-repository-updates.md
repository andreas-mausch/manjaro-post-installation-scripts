---
status: open
status-description: "New source-input layout implemented; migration and end-to-end VM validation pending"
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
Full network-isolated installation, real GitHub update/reboot, rollback and
migration from archived installations remain to be validated. The older
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

- `67ef4cd`, `48b9e5d`, `67889f8`, current README and TODO.
