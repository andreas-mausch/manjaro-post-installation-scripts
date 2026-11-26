---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0001: Installation interface

> Recorded retroactively on 2026-11-26. Date refers to implementation in
> `83db41d`, not a recovered approval date. Earlier wrapper implementations
> predate these ADRs; no supersession IDs are invented for them.

## Context

The installer must deploy this project's existing Flake with user-selected
identity and disk settings. Custom disk provisioning duplicates established
installation logic. The reviewed nixos-wizard did not actually install its
selected source Flake.

A separate TUI installation path is wanted for provisioning servers over SSH.
The graphical installer choice does not satisfy or supersede that requirement.

## Decision

Use the Nixpkgs graphical Calamares Plasma installer with native user,
partitioning, mounting and confirmation pages. Keep a focused Python adapter
for Flake-specific validation, configuration, `nixos-install` and model copying.
Use the official C++ ViewStep interface for the early UEFI requirement.

## Consequences

- **Positive:** Native installation workflows replace custom disk orchestration.
- **Negative:** Every live ISO includes a graphical desktop, even for Base targets.
- **Risks / neutral:** Installation erases the selected whole drive. The former
  wrapper's transport filter and typed wipe phrase no longer apply. Manual
  partitioning stays disabled; UEFI is required. A TUI alternative is future work.

## Options considered

| Option                    | Verdict      | Why                                                        |
| ------------------------- | ------------ | ---------------------------------------------------------- |
| Native Calamares + adapter | ✅           | Reuses existing UI and provisioning with Flake deployment   |
| Custom Python/shell flow  | Replaced     | Duplicated installation and disk-provisioning logic         |
| Disko / disko-install     | Replaced     | Superseded locally by the native graphical workflow         |
| Reviewed nixos-wizard     | Not selected | Its source-Flake field did not control actual installation  |

## References

- Git `0fa1501`, `41ddfb2`, `d53dcc4`, `83db41d`, `7403bfd`.
- Manual partitioning, including safe LUKS layouts, is planned functionality tracked in [TODO](../../TODO.md).
- [Early UEFI verification](../issues/solved/2026-11-25_uefi-validation-too-late.md).

## Candidate investigation: nixos-wizard

Reviewed on 2026-11-25: [km-clay/nixos-wizard](https://github.com/km-clay/nixos-wizard), commit
`386def227ec27ea61bdfd9c3e7afeab7da39102a`, provides a TUI for disk selection, partitioning and user creation,
but does not deploy the selected source Flake:

- The Source Flake menu accepts a local or remote path, but the preview only stores it in unused `_flake_path`.
- Installation copies its generated `configuration.nix` and runs `nixos-install --root /mnt` without `--flake`.
  Entering this project's Flake therefore would not install this configuration.
- The latest main commit at review had a committer date of 2026-04-07. This does not establish abandonment;
  the missing deployment capability, not repository age, is the decisive limitation.

`d53dcc4` records the evaluation, initially retaining Disko with a wrapper; `83db41d` later adopts Calamares
for graphical installation. These observations apply only to the reviewed revision; no later upstream recheck
is recorded. Finding and validating a suitable TUI installer over SSH remains planned work in [TODO.md](../../TODO.md),
not a defect in the current graphical installer.

Sources at the reviewed commit:

- [Source Flake input](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L799-L1023)
- [Configuration preview](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4117-L4203)
- [Installation commands](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4532-L4603)
- [Reviewed commit](https://github.com/km-clay/nixos-wizard/commit/386def227ec27ea61bdfd9c3e7afeab7da39102a)
