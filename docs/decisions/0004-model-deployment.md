---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0004: Model deployment

> Recorded retroactively on 2026-11-26 from implementation and explicit
> integrity-policy evidence on 2026-11-25 (`3562679`).

## Context

AI/Full need approximately 115 GB of pinned weights available offline.
Weights should not become permanent target-system package dependencies.
Users may want Gufo without copying the payload immediately.

## Decision

Fetch all six pinned files during AI/Full ISO builds, verify SHA-256 hashes
and check the repository manifest against the pinned Gufo release manifest.
Offer optional copying in a separate Calamares job. Store installed weights
outside the Nix store under the shared configurable AI model root; preserve
original filenames and the component layout. Configure Gufo with explicit
GGUF/MTP paths, not its alias-based installation layout.

Accept pinned build-time checksums plus successful copying as the integrity
strategy without an additional target checksum pass. Disable SquashFS
compression to avoid compressing the large model payload during packaging.

## Consequences

- **Positive:** Installation can copy models without downloads; omitting copying
  saves target space and does not remove the Gufo configuration.
- **Negative:** AI/Full image size and build-space needs remain large even when
  users later decline copying. Existing weights need manual relocation after
  directory changes. No interactive model-only retry mode exists.
- **Risks / neutral:** Byte progress is not durable-write or checksum proof.
  Model licenses and manifest trust are independent of download verification.
  Local/alternative sourcing is planned, not currently supported.

## Options considered

| Option                             | Verdict      | Why                                                       |
| ---------------------------------- | ------------ | --------------------------------------------------------- |
| Pinned ISO payload, optional copy   | ✅           | Offline availability with independent target-space choice |
| Download on the installed target   | Replaced     | Requires network access during initial model deployment   |
| Scheduled upstream model sync      | Not selected | Does not replace pinned offline deployment or the service |
| Extra installed-file checksum pass | Not selected | Explicitly omitted under the accepted integrity strategy  |
| Gufo alias-based paths             | Not selected | Do not match the shared original-filename layout          |

## References

- Git `0fa1501`, `14e1616`, `688aa83`, `9184204`, `8a788b1`, `3562679`.
- [Copying/progress issue](../issues/solved/2026-11-25_model-copy-failure-and-progress.md).
- [Compression trade-off](../issues/solved/2026-11-25_iso-model-compression-cost.md).
- `modules/generative-ai/models.lock.json`, `modules/generative-ai/default.nix`.
