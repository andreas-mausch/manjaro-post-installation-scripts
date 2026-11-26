# Find a suitable TUI installer for server provisioning over SSH

- Status: Open; suitable TUI installer not yet selected
- Recorded: 2026-11-25

## Goal

Provide a TUI installation path for provisioning servers over SSH, deploying
this project's Flake with user-selected identity and disk settings. Calamares
provides the graphical path but does not replace this requirement. Keep target
modules independent of the installation interface.

Live-installer SSH access requires a separate secure authentication and
network-discovery design; it is currently disabled.

## Candidate investigation: nixos-wizard

Reviewed on 2026-11-25: [km-clay/nixos-wizard](https://github.com/km-clay/nixos-wizard)
has a suitable TUI for SSD selection, partitioning and user creation, but the
reviewed revision does not install an existing Flake such as this configuration.
Reviewed commit: `386def227ec27ea61bdfd9c3e7afeab7da39102a`.

- A Source Flake menu requests a local or remote Flake path.
- The path is saved but appears in the preview only in unused `_flake_path`.
- Installation copies its own generated `configuration.nix` and invokes
  `nixos-install --root /mnt` without `--flake`. Entering this project's Flake
  therefore would not install this configuration.
- The latest main commit at review had a committer date of 2026-04-07, over
  seven months earlier. That does not establish abandonment; the missing
  installation capability, not its age alone, is the decisive limitation.

## Decision and remaining work

`d53dcc4` records the evaluation. Disko with a wrapper was retained at that
stage; `83db41d` later adopted Calamares for graphical installation.
[ADR 0001](../decisions/0001-installation-interface.md) records that choice and
why the reviewed nixos-wizard was not selected; the TUI requirement remains open.

Evaluate suitable TUI tools, including whether nixos-wizard now supports
existing Flake installation. Validate the chosen path over SSH, including
target-disk confirmation and deployment of this project's configuration.
No later upstream recheck is established here; the observations apply to
the reviewed commit, not necessarily current main.

## Sources at the reviewed commit

- [Source Flake input](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L799-L1023)
- [Configuration preview](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4117-L4203)
- [Installation commands](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4532-L4603)
- [Reviewed commit](https://github.com/km-clay/nixos-wizard/commit/386def227ec27ea61bdfd9c3e7afeab7da39102a)
