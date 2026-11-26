---
status: solved
status-description: "Fixed by supported entry-point shapes"
---

# Flake entry-point restrictions prevent directly importing shared definitions
- Resolved: 2026-11-25

## Problem

During extraction of shared build logic, Nix rejected imports/computed values
in root `nixConfig` and a directly imported expression for `outputs`.
Ordinary Nix attribute composition does not imply that every Flake entry-point
field accepts the same shape.

## Solution and verification

`a4588bd` removes root `nixConfig`; daemon cache configuration imports the
shared definition instead. Generated target Flakes forward setup outputs
through an explicit lambda rather than directly importing an outputs expression.
Later installed-archive tests evaluate all five profiles, including writable
host settings and hostname aliases. Configuration approval and cache trust
instructions remain separate from package build logic.

## Evidence

- `a4588bd`, `build/offline-source.nix`, `tests/test_installed_flakes.py`.
- [Related daemon cache problem](2026-11-25_gufo-cache-daemon-trust.md).
