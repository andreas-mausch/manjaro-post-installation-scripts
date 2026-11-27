---
status: open
status-description: "Three-entry firmware selection implemented with virt-firmware; lifecycle unit tests pass, VM test pending"
---

# Direct UKI boot with three retained system generations

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
- The temporary systemd-boot post-install hook now also calls the packaged
  `kernel-bootcfg --add-uki ... --boot-order last`. It keeps the previous default
  first and does not set BootNext. Automatic registration and repetition without
  duplicate entries are now VM-validated.
- Current and previous systems use NixOS profile generations' existing GC
  protection, not additional custom roots. Only the installation baseline has
  an independent permanent root. Do not implement automatic profile deletion;
  additional stored generations may remain beyond the three firmware-menu roles.
- The shared hook now manages at most three project UKI entries: `NixOS Aktuell`,
  `NixOS Backup` and `NixOS Installation`, each with a minute-precision timestamp.
  It remembers the selected generations in
  `/var/lib/my-os-setup/uki/generations.json`. Identical rebuilds retain the backup;
  updates move the previous current generation to backup. Rollback reverses this
  transition. Only superseded entries in `EFI/my-os-setup` on this EFI partition
  are removed, using virt-firmware's EFI model and writing API.
- New installations rerun the entry manager after establishing the permanent
  installation root so that the installation selection appears immediately.
  Existing installations with no such root receive no invented baseline.
- NixOS profiles and Store generations are not deleted. Cached UKI files are
  not yet cleaned up. systemd-boot remains the temporary rescue path; its eventual
  replacement with the external hook remains open.
- Unit tests cover lifecycle, identical rebuild, rollback, fresh baseline,
  removal of legacy entries, preservation of foreign/other-disk entries and
  failure handling. Real firmware lifecycle and new-installation tests are pending.

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

## Next validation

### Further user VM evidence

Screenshots confirm automatic registration as Boot0008, then `Entry exists
(Boot0008)` on an identical rebuild with no duplicate. Linux Boot Manager
remained first. After the date-label change, automatic registration created
Boot000A, `NixOS UKI 2026-11-27 13:53`. Direct firmware selection booted that
entry; BootCurrent was 000A and `/run/booted-system` matched the expected
`dxk6jdzxq0jhmp41cmqq406bw3mj7gbq` system. These checks do not yet cover GC roots.

### Remaining checks

- Current/previous selection from profile generations, identical rebuild,
  rollback, unchanged installation root and GC survival with profiles retained.
- New offline installation with an initial GC root and UKI.
- Current/previous/installation roles, failure handling and GC tests.
- Remove systemd-boot only after these paths work without it.
