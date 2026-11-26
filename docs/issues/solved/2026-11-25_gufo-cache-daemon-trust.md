# Gufo cache settings are ignored by the build-host Nix daemon

- Status: Solved on the recorded build host; cache completeness not guaranteed
- Recorded: 2026-11-25
- Resolved: 2026-11-25

## Problem

Client/Flake cache settings were insufficient when the daemon did not trust
the Gufo substituter and signing key. This could cause large ROCm source
builds. Granting blanket trusted-user access was not necessary.

## Solution and verification

`a2666d8` records daemon cache setup and a post-restart dry run: the untrusted
cache URL warning disappeared and `rocblas-gfx1151` was scheduled for download.
Gufo itself still required a local build. The offline-system dry run planned
235 builds, 3.7 GiB download and 11.0 GiB unpacked; these are historical figures.
The remaining ignored client key warning was redundant because the key was
already configured in the daemon.

`a4588bd` removes root `nixConfig` and centralizes daemon settings in
`modules/generative-ai/cache.nix`. Nix rejects imported/computed values in
root `nixConfig`; sharing this definition avoids duplicated cache literals.
Current setup instructions remain in the README. Do not restart the daemon
during a running ISO build. Trusting the cache is not a guarantee that every
locked derivation has a cached result or that signed builds are correct.

## Evidence

- `a2666d8`, `a4588bd`, historical README and TODO.
