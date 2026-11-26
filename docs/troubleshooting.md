# Installation diagnostics and recovery

[Project overview](../README.md). Current investigations are in [issues/](issues/); completed diagnoses and attempted
fixes are in [issues/solved/](issues/solved/), especially the
[offline investigation](issues/solved/2026-11-25_offline-installation.md).

> A normal installation retry **erases the target drive again** after confirmation. An install-stage failure may leave
> an already partitioned, incomplete system; do not infer success from 100% progress or a partially copied system.

## Save useful diagnostics

Calamares names the failing phase: target mounts, configuration, user setup, system installation or model copying.
Errors include a validation reason, command exit code or OS errno. A system-installation invocation failure does not
identify whether `unshare` or its child `nixos-install` failed. Read the **first original Nix error**, not only
later dependency failures.

Use **Toggle log** for live installation output. The error dialog provides a journal command scoped to the adapter's
start time. For an automatically launched installer, also inspect the live session journal:

```bash
sudo journalctl -b --no-pager
```

Search for `Desktop installer`. For manual launch, save terminal output too. **Save diagnostics before rebooting.**
Adapter command diagnostics omit arguments, passwords and hashes; secret/configuration commands are not streamed to
the UI log. Other inherited stdout/stderr is not necessarily visible there. Original subprocess output is not sanitized:
inspect it for sensitive information before sharing. Nothing is uploaded automatically.

Live logging is user-confirmed in Full; the Desktop VM failure-dialog check of phase reporting, time filtering and
partitioning warnings is [user-confirmed](issues/solved/2026-11-25_installer-failure-diagnostics.md).

## Boot and partitioning requirements

Use UEFI/OVMF, not BIOS. The early welcome extension blocks Next without UEFI; the adapter checks again later.
The early BIOS-rejection path is [VM-verified](issues/solved/2026-11-25_uefi-validation-too-late.md).
No BIOS fallback is planned. Secure Boot must be disabled.

Manual partitioning is disabled: the pinned upstream `dont-allow-manual-luks.patch` removes LUKS/LUKS2 from manual
filesystem dialogs; removing the patch without testing is not a supported workaround. Automatic LUKS2 remains supported.
Swap and hibernation are intentionally unsupported; this is an accepted scope decision, not a pending defect.
Keep no swap selected. See [the installation-interface decision](decisions/0001-installation-interface.md).

## Retry model copying without reinstalling

If system installation succeeded but the separate model-copy job failed, there is no interactive model-only retry mode.
Do **not** repartition a working installation to copy weights.

1. From the live desktop, manually unlock the existing installation if encrypted and mount it at `/mnt`.
   Verify that `/mnt` really is the intended target, not a live filesystem or another disk.
2. Copy from `/etc/desktop-installer/models` using `cp -rL`, so Nix-store symlinks become real target files.
   The default destination is `/mnt/var/lib/generative-ai/models`; use the actual configured model root if customized.
3. Assign files to the installed target's `gufo:gufo` and apply read/write permissions as in the installer job.
   Use the target's identity, not an assumed live-system numeric UID/GID, and preserve the [required layout](ai.md).

Alternatively download the six [manifest files](../modules/generative-ai/models.lock.json), verify their checksums and
place them in the same layout. Gufo's alias-based model installer is not a drop-in replacement.

## Known VM limitations

- [Black screen after idle](issues/2026-11-26_virtmanager-black-screen.md): observed with QXL/SPICE and Plasma/Wayland;
  cause unconfirmed, screen-shutdown countercheck pending.
- [Wayland clipboard](issues/2026-11-26_spice-wayland-clipboard.md): host → guest works with the session agent, but
  guest → host still fails in the recorded VM. The separate
  [autostart workaround](issues/2026-11-26_spice-session-autostart.md)
  does not fix that directional limitation.
