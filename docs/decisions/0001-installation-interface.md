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
- [TUI server installation and nixos-wizard investigation](../issues/2026-11-25_tui-server-installation.md).
- [Manual LUKS limitation](../issues/2026-11-25_manual-luks-partitioning.md).
- [Early UEFI verification](../issues/2026-11-25_uefi-validation-too-late.md).
