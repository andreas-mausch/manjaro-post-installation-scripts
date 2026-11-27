---
status: open
status-description: "Three UKI boots and GC survival verified in Desktop VM; external hook implemented, fresh boot validation pending"
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
- The shared boot integration now uses `boot.loader.external.installHook` to
  invoke the entry manager directly. systemd-boot and GRUB are disabled for all
  target profiles. Current is first in BootOrder; other entries retain their
  relative order. BootNext is not set. Existing systemd-boot files and firmware
  entries are not automatically deleted; fresh installations no longer create them.
- Current and previous systems use NixOS profile generations' existing GC
  protection, not additional custom roots. Only the installation baseline has
  an independent permanent root. Do not implement automatic profile deletion;
  additional stored generations may remain beyond the three firmware-menu roles.
- The shared hook now manages at most three project UKI entries: `NixOS Current`,
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
  not yet cleaned up. systemd-stub remains part of each UKI, not a separate boot manager.
- Unit tests cover lifecycle, identical rebuild, rollback, fresh baseline,
  removal of legacy entries, preservation of foreign/other-disk entries and
  failure handling and identical rebuilds without NVRAM writes. VM evidence below
  predates the external-hook transition; that transition still needs real boot tests.

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

### Remaining checks

- External-hook bootloader build and profile checks for every target profile.
- Fresh UEFI installation without systemd-boot; Current boots by default and all
  three selections boot after an update, with unchanged Installation and GC survival.
- External-hook offline rebuild, local Git fallback and rollback.
- Verify identical rebuilds produce no actual firmware writes in the VM.
- Deliberate removal of legacy systemd-boot from the existing test VM, or replace
  it with a fresh virtual disk and firmware variable store.
- Confirm offline installation, LUKS and target SSH explicitly; real hardware
  and other profiles' end-to-end boot coverage remain pending.
