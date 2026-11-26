---
status: workaround
---

# Black screen after idle in the Plasma/Wayland VM

## Observation

In the existing QXL/SPICE Desktop VM, the display turned black after idle
and did not recover after reconnecting Virt-Manager or sending Ctrl+Alt+F3.
The guest journal shows system services continuing to run; a complete guest
freeze is not established.

The previous boot's journal shows the lock screen starting at 00:55:27,
followed by a DRM hotplug event at 00:56:28 and messages from the lock screen
and PowerDevil: `There are no outputs - creating placeholder screen`.
No kernel entries were recorded in the inspected 00:55–00:57 interval.
The cause and any relation to SPICE remain unconfirmed.

An earlier report of the same symptom on the Bosgame M5 was subsequently
qualified by the user: the M5 responds again, and the earlier wake attempt
may have been incomplete. A reproducible M5 failure is not established; see
[no image after automatic screen shutdown on the M5](2026-11-26_m5-black-screen-after-idle.md).

## Next verification

Automatic screen shutdown was changed to `Never` in the guest's Plasma
power settings; automatic screen locking was left unchanged. Leave the
guest idle for at least ten minutes and check whether the lock screen
appears and can be unlocked normally.

The installed Desktop VM countercheck on 2026-11-26 succeeded with both
screen shutdown and dimming set to `Never`, suspend disabled, and automatic
locking after five minutes. The lock screen remained visible and unlocking
restored a normally responsive desktop. The exact idle duration was not
recorded, so a full ten-minute interval is not established. This supports
the display power-management path as a suspect but does not isolate dimming
from shutdown or prove a shared cause with the M5.

Switching the VM video adapter from QXL to VirtIO-GPU while retaining SPICE
allowed screen shutdown and wake to work, including after automatic screen
locking. Keep VirtIO-GPU as the VM workaround. The QXL root cause remains
unconfirmed; the similar M5 symptom still requires independent investigation.

## Evidence

### Installed QXL test with DRM debugging, 2026-11-26

- SSH login worked immediately after installation as the selected user
  `test`. The VM used QXL; `uname -r` reported **7.3.5**.
- DRM debugging was enabled before reproduction with
  `echo 0x06 | sudo tee /sys/module/drm/parameters/debug`.
- At **21:05:28 +01:00**, `card1-Virtual-1` was `connected`; Virtual-2,
  Virtual-3 and Virtual-4 were `disconnected`.
- With the one-minute screen-shutdown test, the image went black and did
  not return on the user's wake attempt. SSH remained usable. At
  **21:09:50 +01:00**, all four connectors were `disconnected`.
- The supplied kernel-journal excerpt records this sequence:

  ```text
  21:06:58 drm_atomic_helper_commit_crtc_disable: inactive head 0, skip (disable)
  21:06:58 qxl_crtc_atomic_flush: no primary surface, skip (flush)
  21:06:59 qxl_display_read_client_monitors_config: read 0x0+0+0
  21:06:59 Virtual-1: status updated from connected to disconnected
  21:06:59 Virtual-1: generating connector hotplug event
  ```

  QXL reads a zero-size client monitor configuration immediately before
  disconnecting the only connected output. This is direct evidence of the
  disconnect sequence, not proof of which component supplied that
  configuration or why it was not restored. The allocation/free debug
  messages alone do not establish a release-fence hang. Exact matching
  kernel-source inspection remains pending.
- At failure, both guest integration processes were running:
  root's `spice-vdagentd` and user `test`'s `spice-vdagent`, version **0.23.0**.
  `spice-vdagentd.service` was active/running.

### QXL countercheck without guest SPICE agents

- The user followed the reboot-and-stop countercheck, retaining QXL and
  host SPICE. Guest integration was stopped with:

  ```bash
  sudo systemctl stop spice-vdagentd.service
  pkill -x spice-vdagent
  ps -eo pid,user,args | grep '[s]pice-vdagent'
  ```

- The supplied process check returned no process lines. The user confirmed
  DRM debugging was enabled for the new test.
- **One screen-shutdown/wake cycle succeeded:** the screen went black and
  then returned. This contrasts with the failure while agents were running.
  Host SPICE was not removed; this tests guest integration, not all SPICE.
- Guest integration is now a concrete suspect, but one successful cycle
  does not establish causality. No successful-cycle kernel log has yet been
  supplied. Restarting the VM also changed state between the two trials.
- **Next:** repeat shutdown/wake with agents absent, then re-enable both
  agents and repeat with the same display settings. Capture connector state
  and DRM logs in each case. Only then narrow down daemon versus session
  agent and the monitor-configuration sender. No QXL fix is confirmed yet.

### Upstream leads (not confirmed causes)

- [QXL suspend/resume patch, September 2022](https://lkml.iu.edu/hypermail/linux/kernel/2209.0/08069.html):
  describes unrecoverable black screens after system suspend with `driver is
  in bug mode` and GEM/VRAM allocation errors. Our reproduction disabled
  suspend and produced none of these messages; DPMS is not system suspend.
- [QXL unresponsive SPICE host patch proposal, July 2026](https://lkml.iu.edu/hypermail/linux/kernel/2607.3/00892.html):
  describes stalled QXL release fences, unavailable console with SSH alive,
  and possible shutdown hangs. This is a relevant VM-specific lead, but its
  no-client/heavy-console-output trigger, allocation errors and blocked-task
  stacks were not observed here. Neither patch's merge status nor presence
  in the tested kernel has been verified. Neither explains the M5 directly.

### Installed VM reproduction and recovery checks, 2026-11-26

- After changing the VM video adapter to VirtIO-GPU, `virtio_gpu` was loaded.
  The connector initially reported `connected`. Screen shutdown displayed
  `Display output is not active` in Virt-Manager; subsequent input restored
  the desktop. The user also confirmed successful recovery after automatic
  screen locking. SPICE remained in use throughout this comparison.
- With dimming disabled and automatic locking unchanged, enabling screen
  shutdown with a one-minute timeout reproduced the unrecoverable black
  screen. SSH remained usable.
- At guest-local 14:14:10, a DRM hotplug event identified connector 47 on
  `/dev/dri/card1` as `card1-Virtual-1`. Numerous Wayland applications
  reported `There are no outputs - creating placeholder screen`.
- All four `/sys/class/drm/card1-Virtual-*/status` entries reported
  `disconnected`. The active PCI driver was confirmed as `qxl`.
- The kernel journal contained no entries for 14:13–14:16.
- Reopening the Virt-Manager console and changing its size did not recover
  the image or connector status.
- `kscreen-doctor -o`, connected to the actual `wayland-1` socket, reported
  no outputs. An earlier missing `WAYLAND_DISPLAY` caused a diagnostic
  connection failure and is not evidence of compositor failure.
- Restarting NixOS `display-manager.service` did not restore the connectors.
  SDDM was subsequently active and reported successful display-server and
  greeter startup. This rules out a failed restart as the explanation for
  that recovery attempt, but does not uniquely identify the root cause.

The loss is visible at the DRM connector level and persists across a new
graphical session. A purely stale application state is insufficient to
explain it. The QXL/SPICE output path warrants a VirtIO-GPU comparison;
this VM evidence does not establish the cause of the M5 hardware symptom.

- 2026-11-26: User confirmed a visible lock screen and normal unlock in the
  installed VM with shutdown and dimming disabled. Exact idle time unknown.

- `94287c1`: records the observation, journal evidence and pending check.
- Former root `Issues.md`.
