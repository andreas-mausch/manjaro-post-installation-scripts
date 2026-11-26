---
status: solved
status-description: "Later offline Calamares installation confirmed"
---

# Calamares blocks offline installation on its welcome page
- Resolved: 2026-11-25

## Problem and solution

A VM test found that the upstream welcome configuration required Internet
access, preventing the intended offline workflow before installation began.
`3c0cf10` removes the Internet check and requirement, retaining the storage,
RAM, power and screen checks.

## Verification

The extensions built and the resulting welcome configuration was checked.
Later history records an entirely offline Calamares installation and boot
(`7eb2955`, historical README). This is distinct from the subsequent
[offline package-substitution failure](2026-11-25_offline-installation.md).

## Evidence

- `3c0cf10`, `7eb2955`, historical README.
