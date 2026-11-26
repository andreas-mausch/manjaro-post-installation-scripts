---
status: accepted
date: 2026-11-25
deciders: [neonew]
supersedes: []
superseded-by: []
---

# 0010: Validation and evidence

> Recorded retroactively on 2026-11-26. `3562679` explicitly records the user's
> decision to omit further offline regression/variant tests and a target-file
> checksum pass; it does not report those checks as passed.

## Context

The offline investigation demonstrated that a successful system build can
miss live-to-target store transfer, installer behavior and boot. VM results
also cannot establish GPU inference or arbitrary hardware compatibility.

## Decision

Maintain focused adapter, profile and reusable-module checks, plus recorded
installed-archive evaluation. State separate evidence for evaluation, build,
GUI operation, offline installation, boot and updates. Limit VM confirmations
to the tested configuration. Do not add the additional offline regression
and full variant tests retired by user decision; keep omitted coverage explicit.
Use pinned build-time model checksums and successful copying without a second
target-file checksum pass. Retain open runtime diagnostic and GPU checks.

## Consequences

- **Positive:** Test claims remain traceable and do not overstate what a lower
  layer or a user confirmation proves. Validation work stays bounded.
- **Negative:** Not every offline profile or post-refactor ISO has end-to-end
  coverage; regressions in untested paths may escape focused checks.
- **Risks / neutral:** Accepted architecture is not a claim of complete runtime
  verification. Further tests can be adopted through a new decision.

## Options considered

| Option                            | Verdict       | Why                                                    |
| --------------------------------- | ------------- | ------------------------------------------------------ |
| Scoped automated/manual evidence  | ✅            | Reflects the actual checked behavior                   |
| Extra offline/variant regressions | Not adopted   | Retired by explicit user decision, not recorded passed |
| Additional target checksum pass   | Not adopted   | Explicitly omitted under the model-integrity strategy  |
| Infer install/boot from build     | Invalid claim | Separate-store and runtime failures disproved it       |

## References

- Git `19833a5`, `886ef3e`, `7eb2955`, `9cf72b2`, `3562679`, `27c3ddb`.
- [Offline test limitations](../issues/solved/2026-11-25_offline-installation.md).
- [User-confirmed failure-dialog checks](../issues/solved/2026-11-25_installer-failure-diagnostics.md).
- [Pending GPU verification](../issues/2026-11-25_gufo-hardware-backend-validation.md).
- [ADR-0004](0004-model-deployment.md): model integrity policy.
