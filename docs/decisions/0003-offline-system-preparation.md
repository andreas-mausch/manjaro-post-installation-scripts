---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0003: Offline system preparation

> Recorded retroactively on 2026-11-26. Implementation and correction evidence
> comes from `5bf86fd`, `19833a5`, `886ef3e` and `38135af` on the metadata date.

## Context

Installation must allow changed identity, language and filesystem UUIDs without
rebuilding the complete desktop/kernel/ROCm toolchain or downloading sources.
A runtime package closure alone is insufficient for these assembly steps.
The installer and target use separate stores.

## Decision

Bundle each profile's prebuilt reference system and targeted system/initrd
assembly tools, a shared all-locales archive and selected locked input sources.
Rewrite input locks to local store paths, retain the online lock, and retain
sources through target extra dependencies. Preserve revision-sensitive Gufo
outputs. Enable substitution and `always-allow-substitutes` for `nixos-install`
without persisting those overrides into the installed system.

Keep networking available during normal installation; block it when verifying
offline completeness rather than as a permanent installer restriction.

## Consequences

- **Positive:** Dynamic host settings can reuse prepared outputs and archived inputs.
- **Negative:** Images contain both a live environment and a prepared target;
  assembly dependencies need maintenance across updates.
- **Risks / neutral:** This is not every source/compiler dependency or every
  hardware driver. Local system builds do not prove installation or boot.
  Later online updates can replace local locks with network inputs.

## Options considered

| Option                          | Verdict      | Why                                                       |
| ------------------------------- | ------------ | --------------------------------------------------------- |
| Prepared outputs + direct tools | ✅           | Supports dynamic assembly without the full compiler graph |
| Runtime closure alone           | Insufficient | Missed system-path and other assembly dependencies        |
| Full build-dependency closure   | Not selected | Would retain large kernel/ROCm sources and toolchains      |
| Disable normal-install sources  | Removed      | Overwrote live-store substitution and prevented reuse      |

## References

- Git `5bf86fd`, `19833a5`, `886ef3e`, `38135af`, `a4588bd`, `d547bdc`.
- [Offline investigation and evidence](../issues/solved/2026-11-25_offline-installation.md).
- [Gufo package identity](../issues/solved/2026-11-25_gufo-offline-package-identity.md).
- [ADR-0007](0007-package-source-trust.md): independent signature policy.
