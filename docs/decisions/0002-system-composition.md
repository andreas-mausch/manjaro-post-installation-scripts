---
status: accepted
date: 2026-11-26
deciders: []
supersedes: []
superseded-by: []
---

# 0002: System composition

> Recorded retroactively on 2026-11-26. Date represents the current profile
> and import-interface implementation, not a recovered approval date.

## Context

Several system presets must share settings without duplicating configurations.
Reusable modules must not load repository-local users, hardware or placeholder
filesystems. AI must also be usable without KDE.

## Decision

Compose Base, Desktop, Gaming, AI and Full through `profiles/`. Desktop imports
Base; Gaming imports Desktop; AI adds the independent AI module to Desktop;
Full adds it to Gaming. Keep Base/Desktop/Gaming settings directly in their
profiles. Import profiles and modules by file path, without `nixosModules`
exports. Bind local/reference settings through `modules/target-configuration.nix`.
Keep ISO and offline orchestration under `build/`, not installer integration.

## Consequences

- **Positive:** Shared settings have one owner; modules work with independent
  consumer hardware and users. The root Flake mainly wires inputs and outputs.
- **Negative:** Consumers need to know the import paths; AI requires `gufoPackage`.
- **Risks / neutral:** Profiles are presets, not a runtime feature-selection UI.
  The broader pinned-input host-update workflow remains unimplemented.

## Options considered

| Option                            | Verdict | Why                                                    |
| --------------------------------- | ------- | ------------------------------------------------------ |
| Profiles with direct imports      | ✅       | Makes prerequisites explicit without redundant exports |
| Separate wrapper for each feature | Removed  | Added indirection for small Base/Desktop/Gaming files   |
| Public nixosModules registry       | Removed  | Was an extra interface used only by tests               |
| Local host settings inside Base   | Removed  | Coupled reusable configuration to repository state      |

## References

- Git `456623e`, `67889f8`, `ff11493`, `161a8cf`, `5920d33`, `87e3e7d`.
- `profiles/`, `build/`, `modules/target-configuration.nix`.
- [Host-update limitation](../issues/2026-11-25_installed-system-repository-updates.md).
