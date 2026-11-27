---
status: solved
status-description: "Solved and validated in the Desktop UEFI VM; broader hardware and regression coverage tracked separately"
---

# Direct UKI boot with three retained system generations

- Resolved: 2026-11-27

Direct UKI boot is implemented and validated for the fresh Desktop UEFI VM:
NixOS boots by default without systemd-boot, and all three stable selections
boot after an update. Identical rebuilds preserve firmware entry numbers and
BootOrder. Remaining hardware and regression checks are tracked in `TODO.md`
and summarized below; they do not represent unfinished UKI implementation.

## Goal

UEFI boots full UKIs directly without systemd-boot or GRUB. Keep the current
system, its predecessor and the original installation system bootable and
GC-protected. The installation baseline changes only on full reinstallation.

## Implementation status

- The shared base profile includes UKI preparation from the actual target
  bootspec using `ukify` and systemd-stub. This is independent of the chosen
  profile and does not require a separate Calamares UKI build.
- New Calamares installations retain the initial target closure through
  `/nix/var/nix/gcroots/nixos-install`. Existing installations do not acquire an
  original baseline through an update. General UI-independent installation
  hooks remain a separate TODO.
- The shared boot integration now uses `boot.loader.external.installHook` to
  invoke the entry manager directly. systemd-boot and GRUB are disabled for all
  target profiles. Current is first in BootOrder; other entries retain their
  relative order. BootNext is not set. Existing systemd-boot files and firmware
  entries are not automatically deleted; fresh installations no longer create them.
- Current and previous systems use NixOS profile generations' existing GC
  protection, not additional custom roots. Only the installation baseline has
  an independent permanent root. Do not implement automatic profile deletion;
  additional stored generations may remain beyond the three firmware-menu roles.
- The shared hook now manages at most three stable project UKI entries: `NixOS`,
  `NixOS (Previous)` and `NixOS (Installation)`, without timestamps. They point to
  `EFI/my-os-setup/nixos.efi`, `nixos-previous.efi` and `nixos-installation.efi`.
  The builder writes directly to these filenames, replacing Previous and
  Installation before the default UKI. A `.generation` sidecar records the
  built system path to skip unchanged builds. Each changed file is
  replaced atomically, but the three replacements are not one transaction.
  Updates reuse the firmware entries rather than writing NVRAM for each generation.
  Legacy dated project entries on this partition are removed during migration.
  It remembers the selected generations in
  `/var/lib/my-os-setup/uki/generations.json`. Identical rebuilds retain the backup;
  updates move the previous current generation to backup. Rollback reverses this
  transition. Only superseded entries in `EFI/my-os-setup` on this EFI partition
  are removed, using virt-firmware's EFI model and writing API.
- New installations rerun the entry manager after establishing the permanent
  installation root so that the installation selection appears immediately.
  Existing installations with no such root receive no invented baseline.
- NixOS profiles and Store generations are not deleted. New installations create
  only the three stable UKI files and their generation sidecars, not a growing
  collection. Generation-named UKIs from older installations are not deleted
  automatically; fresh installations have none and need no such cleanup.
  systemd-stub remains part of each UKI, not a separate boot manager.
- Unit tests cover lifecycle, identical rebuild, rollback, fresh baseline,
  removal of legacy entries, preservation of foreign/other-disk entries and
  failure handling and identical rebuilds without NVRAM writes. Entry tests,
  external-hook builds for all target profiles, installer/profile checks,
  formatting and whitespace checks passed before the implementation commits.

## User VM evidence, 2026-11-27

The user updated the installed non-Flake project input to
`065a666cb4a6b82f3abfffaf71a34f458631808e` and successfully rebuilt the Desktop
system. The target UKI was generated on the EFI partition, about 60 MiB.

Registration without adding the entry to BootOrder succeeded initially, but
the firmware menu did not display it. After reboot, `--update-uki` could no
longer find the entry. Firmware removal is a possible explanation, not proven.
Registering with `--boot-order last` created entry `0007`, which appeared in
the firmware menu. The user selected it and booted successfully.

The subsequent screenshot confirms BootCurrent `0007` (`NixOS UKI Test`) and
the exact expected `/run/booted-system`:

```text
/nix/store/0x4qf9j9y0lqg4azfzf2cb0wj0h990xc-nixos-system-test-standardpc-26.11.20261121.2786a2a
```

This verifies manual direct UKI boot in this QEMU/KVM UEFI VM, not fresh ISO
installation, LUKS, Secure Boot, other profiles' real boots, generation rotation,
GC survival or Bosgame hardware. systemd-boot remains installed as a rescue path.

## Further VM evidence

### Further user VM evidence

Screenshots confirm automatic registration as Boot0008, then `Entry exists
(Boot0008)` on an identical rebuild with no duplicate. Linux Boot Manager
remained first. After the date-label change, automatic registration created
Boot000A, `NixOS UKI 2026-11-27 13:53`. Direct firmware selection booted that
entry; BootCurrent was 000A and `/run/booted-system` matched the expected
`dxk6jdzxq0jhmp41cmqq406bw3mj7gbq` system. These checks do not yet cover GC roots.

### Fresh Desktop installation and update

The personalized Desktop ISO built from `ab17f13` included the supplied public
SSH key and excluded the local `Plan.md`. The user confirmed SSH access (the
conversation does not establish separately whether this was live or target SSH).

Fresh UEFI installation created Current and Installation, both labelled
`2026-11-27 20:28`. The user booted each directly and supplied screenshots showing
that `/run/current-system` and `/nix/var/nix/gcroots/nixos-install` matched the
initial system generation. The initially black Installation screen was a delay,
not a failed boot; the desktop subsequently appeared.

After `nix flake update --flake path:/etc/nixos` and `nixos-rebuild switch`,
Current was labelled `20:33`, with Backup and Installation retaining `20:28`.
Screenshots confirmed a new current system path and the unchanged installation
root. The user confirmed successful direct UEFI boots of all three selections.

`nix-store --gc` deleted 85 Store paths and freed 107.5 MiB; `readlink -e` still
resolved the installation root. The user's subsequent confirmation indicates
the Installation boot remained usable. Profile generations were retained, so
this verifies GC survival but does not isolate protection by the installation
root alone. Network-disabled installation and LUKS coverage were not established
by the supplied screenshots.

### Stable entries and external hook: fresh installation

The subsequent personalized Desktop ISO was built from `3e62360`, including
the external-hook transition in `1c928e8`. Its retained repository commit and
supplied public SSH key were checked; the local `Plan.md` was excluded.
The user requested a fresh installation test rather than an in-place migration.
The conversation does not separately establish the disk/NVRAM reset procedure.

The user confirmed successful fresh installation and default boot, then
successful update and boot of all three selections with the stable names.
A screenshot of `kernel-bootcfg --show` confirms:

```text
BootCurrent: 0008
0008  NixOS                 first in BootOrder
0002  UEFI Misc Device
0009  NixOS (Installation)
000a  NixOS (Previous)
0000  BootManagerMenuApp
0001  EFI Firmware Setup
```

No Linux Boot Manager entry appears. This supports the fresh direct-UKI boot
result; the screenshot alone is not an inventory of all EFI-partition files.

With no further dependency update available, the user compared firmware state
before and after an identical `nixos-rebuild switch` and confirmed no change.
The three entry numbers and BootOrder therefore remained stable for that repeat.
The user subsequently performed a real update and confirmed that the three
UEFI entry numbers remained stable. This completes the update comparison;
no additional before/after screenshot was supplied. Unchanged displayed state
does not prove absence of actual NVRAM writes; no-write behavior is covered by
unit tests, not a VM write trace.

The user also confirmed the final stable-file GC test (including the requested
Installation boot after GC), offline rebuild and local Git fallback with the
external hook. These are user-reported successes; no additional command logs
were supplied. Rollback was not part of this latest confirmation.

The agreed UKI implementation is complete for the intended use. Remaining items
below are validation coverage or separate installation/hardware work, not a
reason to add more UKI infrastructure. Both the earlier temporary integration
and the final stable-file implementation now have user-confirmed GC coverage.

### Remaining coverage and separate work

- Rollback with the final external-hook implementation.
- Verify identical rebuilds produce no actual firmware writes in the VM.
- In-place migration from an older installation, if needed: legacy systemd-boot
  files and old generation-named UKIs are not automatically removed. This is not
  required for the user's fresh-installation path.
- Confirm offline installation, LUKS and target SSH explicitly; real hardware
  and other profiles' end-to-end boot coverage remain pending.
