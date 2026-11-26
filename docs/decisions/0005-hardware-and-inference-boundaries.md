---
status: accepted
date: 2026-11-25
deciders: []
supersedes: []
superseded-by: []
---

# 0005: Hardware and inference boundaries

> Recorded retroactively on 2026-11-26. Generalization was implemented in
> `1990ec8`; the manual-start service already existed in `521af73`.

## Context

The project began on a Bosgame M5, but desktop installation should not force
that machine's GPU drivers or memory limits on other hosts. Gufo and games
share GPU/memory resources, and a desktop VM cannot verify GPU inference.

## Decision

Let generated hardware configuration select drivers and CPU microcode; do
not impose M5-specific AMD drivers or GPU memory limits. Keep Gufo manually
started, without a boot target, and bind its API to localhost. Preserve the
pinned release backend while explicitly limiting compatibility claims to
what that backend supports; do not advertise generic GPU inference support.

## Consequences

- **Positive:** Desktop installation is independent of M5-specific tuning;
  stopping Gufo releases resources for other workloads.
- **Negative:** Users must start Gufo and adapt inference settings/backends
  for their hardware. The pinned backend targets AMD Strix Halo `gfx1151`.
- **Risks / neutral:** `gufo --version` proves availability, not working
  inference. Real-hardware/passthrough validation remains outstanding.

## Options considered

| Option                       | Verdict      | Why                                                       |
| ---------------------------- | ------------ | --------------------------------------------------------- |
| Generated hardware settings  | ✅           | Keeps machine-specific settings with the actual host      |
| Forced M5 drivers and limits  | Removed      | Inappropriately constrains other hosts                    |
| Manual, localhost-only Gufo  | ✅           | Keeps inference access/resource use explicitly controlled |

## References

- Git `521af73`, `1990ec8`.
- [Backend verification issue](../issues/2026-11-25_gufo-hardware-backend-validation.md).
- `modules/generative-ai/default.nix`.
