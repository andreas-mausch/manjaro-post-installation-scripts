# nixos-wizard does not install the selected source Flake

- Status: Open upstream capability gap; avoided locally by using Calamares
- Recorded: 2026-11-25

## Observation

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
stage; `83db41d` later adopted Calamares. Reassess nixos-wizard when existing
Flake installation works. No later upstream recheck is established here;
the observations apply to the reviewed commit, not necessarily current main.

## Sources at the reviewed commit

- [Source Flake input](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L799-L1023)
- [Configuration preview](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4117-L4203)
- [Installation commands](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4532-L4603)
- [Reviewed commit](https://github.com/km-clay/nixos-wizard/commit/386def227ec27ea61bdfd9c3e7afeab7da39102a)
