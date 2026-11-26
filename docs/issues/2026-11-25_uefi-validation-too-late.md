# BIOS boot is detected only after the installer has progressed too far

- Status: Early check implemented; BIOS/UEFI runtime verification pending
- Recorded: 2026-11-25

## Problem and correction

The system requires UEFI, but the adapter preflight runs later in the
workflow. Users should be blocked on the welcome page rather than discover
the requirement during deployment.

`7403bfd` adds `uefiwelcome`, a C++ ViewStep that loads the unchanged native
welcome page and adds a mandatory UEFI requirement. It blocks Next in BIOS
mode and requests UEFI/OVMF boot; the later preflight remains a safeguard.
Calamares 3.4.2 Python jobs do not expose this early requirements hook, so
the implementation uses the official C++ interface rather than patching
partitioning or adding another wizard page.

## Verification

The plugin built; evaluation and formatting passed. Normal UEFI installs
later succeeded, but that does not verify the BIOS rejection path. The
current README still identifies early validation as needing VM confirmation.

## Evidence

- `7403bfd`, `modules/installer/calamares/welcome/`, historical README.
