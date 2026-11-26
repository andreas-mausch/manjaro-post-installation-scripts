---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0006: Host configuration and secrets

> Recorded retroactively on 2026-11-26. Date marks editable configuration
> implementation (`48b9e5d`), not a recovered approval date.

## Context

Installed users need editable local settings and standard rebuild commands
without modifying shared profiles. Password hashes must not enter the Flake,
Nix store, command arguments or installer output.

## Decision

Generate local `configuration.nix` with identity, language, existing stateVersion
and hardware imports. Store only installation metadata in `installation.json`;
expose both the profile target and an alias for the configured hostname.
Keep the root-protected password hash at `/var/lib/nixos-secrets/user-password.hash`.
Use declarative immutable users with root locked. Capture file-write stdout.
Keep PC-specific files out of shared commits and use explicit `path:` rebuilds
when ignored/untracked host files are needed in a checkout.

## Consequences

- **Positive:** Shared profiles remain reusable; local administration has one
  editable configuration, and ordinary hostname-based rebuilds are supported.
- **Negative:** Persistent password changes require replacing the hash file;
  plain `passwd` is not a persistent declarative change. Checkout rebuilds
  currently need PC files copied separately.
- **Risks / neutral:** Generated host files are not secrets, but are specific
  to a PC. Earlier logs may contain hashes. The pinned-input update workflow
  that avoids copying PC files remains future work.

## Options considered

| Option                             | Verdict      | Why                                                      |
| ---------------------------------- | ------------ | -------------------------------------------------------- |
| Editable local Nix configuration   | ✅           | Separates host administration from shared system policy   |
| Identity only in installation.json | Replaced     | Did not provide the current editable configuration model |
| Password hash in Flake/store       | Not selected | Would distribute sensitive data through source/store     |
| Implicit Git Flake for local files | Not suitable | Omits ignored/untracked host configuration               |

## References

- Git `521af73`, `67ef4cd`, `48b9e5d`, `5cecccc`, `344e241`.
- [Host updates](../issues/2026-11-25_installed-system-repository-updates.md).
- [File-write output exposure](../issues/solved/2026-11-26_installer-echoes-file-contents.md).
