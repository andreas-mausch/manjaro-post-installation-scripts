---
status: "Solved; online/offline package-path comparison recorded"
---

# Local offline Flake inputs change Gufo's revision-dependent package identity
- Resolved: 2026-11-25

## Problem

Archived path inputs do not provide the same short Git revision as network
inputs. Gufo uses revision-dependent build arguments; losing that revision
would change its store path and prevent reuse of the prebuilt release offline.

## Solution and verification

`5bf86fd` recovers the original short revision from the online lock.
`a4588bd` preserves the original setup entry point for revision-sensitive
outputs; `d547bdc` isolates package construction in `gufo.nix`.
The archived Flake evaluates with registry and remote substituters disabled.
The recorded online/offline comparison found identical system package paths
except the newly generated `nixos-version` script. Later archive tests cover
all profiles. These checks are not GPU inference evidence.

## Evidence

- `5bf86fd`, `a4588bd`, `d547bdc`, historical README.
- `modules/generative-ai/gufo.nix`, `build/offline-source.nix`.
