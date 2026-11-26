---
status: "Mitigated by disabling compression; no benchmark recorded"
---

# SquashFS compression spends excessive CPU on the bundled model payload
- Resolved: 2026-11-25

## Problem and trade-off

AI/Full images bundle roughly 115 GB of model files. Compressing that payload
during ISO packaging adds substantial CPU work. `14e1616` sets
`isoImage.squashfsCompression = null`, trading a larger image for reduced
compression work. It deliberately left the already running ISO build alone.

## Verification

The evaluated option was checked and formatting passed. Current profile tests
retain the uncompressed-image contract; later ISO builds succeeded. No
quantitative before/after packaging benchmark is recorded, so the issue does
not claim a measured speedup or guaranteed space reduction.

## Evidence

- `14e1616`, `build/live.nix`, `tests/profiles.nix`, current README.
