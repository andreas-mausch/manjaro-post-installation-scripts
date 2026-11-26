---
status: accepted
date: 2026-11-26
deciders: [neonew]
supersedes: []
superseded-by: []
---

# 0012: Firewall backend

## Context

Base enables the NixOS firewall without explicitly selecting its backend.
For this fresh setup, use the modern nftables backend rather than relying on
the implicit iptables default. This is a maintenance choice, not evidence
that iptables is insecure or that nftables improves measured performance.

## Decision

Enable `networking.nftables.enable` in the shared networking module used by
live and installed profiles. Keep the NixOS firewall and its declarative
port/interface options; do not introduce a separate firewall manager.

Do not add port 3333 or any other new inbound-port exception to the shared
repository. Service exposure remains an explicit host-local decision.
Temporary runtime exceptions are not persistent host configuration.

## Consequences

- **Positive:** Explicit, shared backend policy using nftables.
- **Negative:** Existing host-local iptables commands and custom rules need
  review when switching backends; they are not translated automatically.
- **Risks / neutral:** Evaluation tests do not establish runtime connectivity.
  Verify required access when migrating a remote server and retain recovery
  access. A listening service and upstream network policy still determine
  whether a permitted connection can reach the application.

## Options considered

| Option                    | Verdict      | Reason                                                    |
| ------------------------- | ------------ | --------------------------------------------------------- |
| NixOS nftables backend    | ✅           | Explicit modern backend for fresh setup                   |
| Implicit iptables backend | Not selected | Supported, but not the requested policy                    |
| UFW                       | Not selected | Additional manager; prefer native declarative NixOS rules  |
| firewalld                 | Not selected | Additional manager; dynamic zones are not required here    |

UFW provides a convenient imperative command-line interface, while firewalld
supports dynamic zones and runtime policy changes. Neither is required for
temporary port access: NixOS provides `nixos-firewall-tool` for that purpose.
Replacing the native firewall would require separate integration; running
multiple managers over the same ruleset would create competing ownership.

## References

- User decision on 2026-11-26.
- Pinned Nixpkgs `nixos/modules/services/networking/firewall-nftables.nix`.
- Pinned Nixpkgs `pkgs/by-name/ni/nixos-firewall-tool/`.
