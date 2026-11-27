---
status: open
status-description: "Manual direct UKI boot verified in Desktop VM; automatic registration and generation retention pending"
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
  first and does not set BootNext. This automatic step is not yet VM-validated.
- Three-role rotation, targeted cleanup and replacement of systemd-boot with
  the external bootloader hook remain unimplemented.

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

- Automatic registration during rebuild, repeated rebuild without duplicates,
  unchanged existing default and another direct UKI boot.
- New offline installation with an initial GC root and UKI.
- Current/previous/installation roles, failure handling and GC tests.
- Remove systemd-boot only after these paths work without it.
