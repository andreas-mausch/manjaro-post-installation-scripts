# Generic installation does not establish Gufo GPU compatibility

- Status: Open; hardcoded host assumptions removed, inference unverified
- Recorded: 2026-11-25

## Problem and mitigation

The initial setup targeted a Bosgame M5 with AMD Strix Halo and included
machine-specific GPU memory limits and forced AMD drivers. `1990ec8` removes
these assumptions and delegates drivers/microcode to generated hardware
settings, also adding Intel microcode to offline assembly tools.

The pinned Gufo v0.36.0 package still uses its upstream ROCm `gfx1151` backend.
Other GPUs require a suitable backend or different build. A successful KDE
installation or `gufo --version` does not prove GPU inference works.

## Remaining verification

Test Gufo inference and the model on suitable real hardware or with GPU
passthrough. Memory limits and context settings must fit the actual device.
The recorded VM cannot establish this without GPU passthrough. Arbitrary
hardware drivers are not guaranteed to be available offline.

## Evidence

- `521af73`, `1990ec8`, current README and `TODO.md`.
