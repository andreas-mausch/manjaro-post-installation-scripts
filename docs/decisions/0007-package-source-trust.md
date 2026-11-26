---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0007: Package source trust

> Recorded retroactively on 2026-11-26 from the source-scoped trust
> investigation and implementation on 2026-11-25.

## Context

Offline installation transfers locally built unsigned outputs into a separate
store. Online caches should retain signature verification. Gufo cache use
also requires explicit daemon trust, not merely client-side configuration.

## Decision

Retain signature verification and rely on `nixos-install`'s source-specific
`auto?trusted=1` live-store substituter for trusted ISO outputs. Do not globally
disable `require-sigs` or persist diagnostic exceptions. Configure the optional
Gufo cache and signing key in the daemon using the shared cache definition;
do not require blanket trusted-user access or root Flake `nixConfig`.

## Consequences

- **Positive:** Local unsigned outputs can be reused while online sources keep
  their independent signature requirements.
- **Negative:** The ISO and live store become an explicit trust boundary;
  cache configuration needs host administration.
- **Risks / neutral:** Substituter trust does not apply automatically to direct
  `nix copy`. Trusted signatures prove provenance/integrity, not correctness.
  Configuring a cache does not guarantee an output is available there.

## Options considered

| Option                            | Verdict         | Why                                                   |
| --------------------------------- | --------------- | ----------------------------------------------------- |
| Source-specific substituter trust | ✅              | Limits the local exception to the trusted ISO source   |
| Global require-sigs=false         | Diagnostic only | Unnecessarily weakens independent source checks       |
| Direct unsigned nix copy          | Not suitable    | Does not inherit substituter-specific trust            |
| Blanket trusted-users access      | Not required    | Daemon cache/key configuration suffices for cache use  |

## References

- Git `a2666d8`, `8a801cf`, `77f68bf`, `38135af`, `a4588bd`.
- [Offline signature tests](../issues/solved/2026-11-25_offline-installation.md).
- [Daemon cache setup](../issues/solved/2026-11-25_gufo-cache-daemon-trust.md).
- [ADR-0003](0003-offline-system-preparation.md).
