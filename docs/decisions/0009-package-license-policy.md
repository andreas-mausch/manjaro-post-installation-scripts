---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0009: Package license policy

> Recorded retroactively on 2026-11-26 from `456623e` and `2f8a7ff`.

## Context

Gaming requires Steam, but that exception should not authorize every unfree
package in every profile. Firmware and model weights have separate licensing
considerations, so an application-package policy is not a complete image audit.

## Decision

Do not allow unfree packages globally. Gaming and Full permit only `steam`
and `steam-unwrapped` through `allowUnfreePredicate`. Keep redistributable
firmware enabled through the separate hardware option. Describe Base/Desktop/AI
as allowing free application packages, not as audited entirely free images.
Treat model licenses separately.

## Consequences

- **Positive:** Steam exceptions are explicit and scoped to the relevant presets.
- **Negative:** Additional unfree applications need an intentional policy change.
- **Risks / neutral:** Firmware redistribution is not the same as free software.
  An SBOM/license audit is planned, not currently supplied by this policy.

## Options considered

| Option                      | Verdict  | Why                                                |
| --------------------------- | -------- | -------------------------------------------------- |
| Scoped Steam allowlist      | ✅       | Provides Gaming without a blanket unfree allowance |
| Global allowUnfree          | Removed  | Authorized unrelated unfree packages                |
| Claim the whole ISO is free | Avoided  | Ignores firmware/model licenses and audit limits    |

## References

- Git `456623e`, `2f8a7ff`.
- `profiles/gaming.nix`, `profiles/base.nix`, root README profile table.
- `TODO.md`: separate target/live SBOM evaluation.
