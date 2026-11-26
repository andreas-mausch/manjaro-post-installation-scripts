---
status: solved
status-description: "Subprocess-boundary regression test added"
---

# Installer file writes echo password hashes and local configuration
- Resolved: 2026-11-26

## Problem

Target file writes used `tee` with inherited stdout. This could echo the
password hash and generated local configuration into installer output.
Keeping secrets outside the Nix store did not prevent this output exposure.

## Solution and verification

`344e241` captures stdout for these writes in the Calamares adapter while
retaining stderr and command failure handling. Its regression test verifies
that file contents are captured at the subprocess boundary, not inherited.
No runtime log audit of a newly built ISO is recorded for this correction.
Previously produced logs may still contain sensitive information; inspect
them before sharing. This issue does not claim plaintext password exposure.

## Evidence

- `344e241`: diagnosis, correction and regression test.
- `modules/installer/calamares/main.py`, `tests/test_calamares.py`.
