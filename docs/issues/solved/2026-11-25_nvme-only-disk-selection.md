---
status: "Fixed in the former installer; superseded by native Calamares selection"
---

# Early installer excludes SATA and VirtIO target disks
- Resolved: 2026-11-25

## Problem and correction

The original installer only accepted NVMe disks, excluding common VM storage
and SATA targets. `0c77c81` adds SATA and VirtIO support, recognizes VirtIO
paths without a reported transport and retains USB/removable/read-only/
mounted exclusions, minimum size and typed erase confirmation.

## Verification and current scope

All nine then-existing safety tests passed, including transport and partition
naming tests. Full installation was untested at that stage.
`83db41d` later replaces this wrapper with Calamares' native disk selection.
The old transport filter and typed wipe phrase are no longer present; the
native summary and final confirmation are the current safeguards.

## Evidence

- `0c77c81`, `83db41d`, historical README.
