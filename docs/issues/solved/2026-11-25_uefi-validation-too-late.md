---
status: solved
status-description: "BIOS rejection confirmed on the welcome page in the Desktop VM; earlier UEFI installs succeeded"
---

# BIOS boot is detected only after the installer has progressed too far

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
later succeeded.

On 2026-11-26, the user tested the newly built Desktop ISO in a QEMU/KVM VM
booted in BIOS mode and supplied a screenshot. Calamares displays the failure
on the welcome page, states that installation cannot continue, requests a
restart in UEFI mode (UEFI/OVMF for VMs), and disables Next. This confirms the
previously unverified early BIOS-rejection path without entering deployment.

The screenshot also shows the requirement message exceeding the visible width
and a horizontal scrollbar. This is a presentation limitation, not a failure
of the boot-mode check; no text-wrapping correction has been verified.

## Evidence

- `7403bfd`, `modules/installer/calamares/welcome/`, historical README.
- User-provided Desktop VM screenshot on 2026-11-26 showing BIOS rejection
  on the welcome page and disabled Next.
