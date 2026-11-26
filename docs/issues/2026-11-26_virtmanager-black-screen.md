---
status: closed
status-description: "Closed with accepted VirtIO-GPU workaround; QXL root cause unconfirmed."
---

# Black screen after idle in the Plasma/Wayland VM

## Closure, 2026-11-26

Closed at the user's request with an accepted workaround, **not a confirmed
QXL root-cause fix**. Use **VirtIO-GPU without 3D**, retaining SPICE, for the
user's Linux VMs. Wake with VirtIO was confirmed, including after screen lock.

For QXL, disabling automatic guest resizing in Virt-Manager also allowed
**two successful shutdown/wake cycles with both guest agents running**.
This implicates the automatic monitor-management path, but does not prove
whether spice-gtk, QXL, or their interaction is faulty.

Further investigation is paused. Historical next steps below are retained
for a possible reopening, not active work. The upstream issue draft at
`spice-gtk-issue-draft.md` was not submitted and is retained only in Git
history (commit `84ffed9`).

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

## Historical verification

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

### Repeated counterchecks and session-agent isolation

- With both guest agents stopped, the user confirmed a **second successful**
  screen-shutdown/wake cycle.
- Without rebooting, the user restarted `spice-vdagentd.service` and then
  the session agent. Starting `spice-vdagent` over SSH silently exited with
  code 1; at that point only the root daemon was running. Starting it from
  the KDE desktop terminal succeeded, and the user confirmed both processes
  were running before the next test.
- With both agents restored and display settings unchanged, shutdown/wake
  failed again. All four DRM connectors were `disconnected`. The supplied
  filtered kernel journal showed:

  ```text
  21:24:11 drm_atomic_helper_commit_crtc_disable: inactive head 0, skip (disable)
  21:24:11 qxl_crtc_atomic_flush: no primary surface, skip (flush)
  21:24:12 qxl_display_read_client_monitors_config: read 0x0+0+0
  21:24:12 Virtual-1: status updated from connected to disconnected
  21:24:12 Virtual-1: generating connector hotplug event
  ```

- For the next countercheck, the user followed the reboot-and-session-agent-
  stop procedure, leaving `spice-vdagentd` running. The user reported that
  the screen went black and **returned on wake**. No separate process listing
  or successful-cycle kernel log was supplied for this trial.

| Guest integration | Observed wake result |
| ----------------- | -------------------- |
| Both agents stopped | Two successful cycles |
| Both agents running again, without reboot | Failure; zero-size monitor configuration and connector loss |
| Only root daemon, session agent stopped (reported test setup) | One successful cycle |

These counterchecks strongly implicate the **user-session `spice-vdagent`**
in the trigger under this QXL configuration, rather than requiring removal
of host SPICE or the root daemon. They do not yet prove that the session
agent itself originates the zero-size client monitor configuration; the
daemon, host and client interactions still need tracing.

**Targeted QXL workaround candidate:** keep the user-session agent disabled
while retaining QXL, host SPICE and `spice-vdagentd`. This was tested by
temporarily stopping the agent; a persistent configuration change and its
effects on clipboard, resizing and other guest integration have not been
implemented or verified. VirtIO-GPU remains the previously confirmed VM
workaround. No root-cause repair is confirmed.

**Next investigation:** inspect the matching session-agent/daemon and QXL
sources, trace the monitor-configuration propagation during display shutdown,
and test a narrowly scoped fix with guest integration enabled. Do not equate
this VM finding with the unconfirmed Bosgame report.

### Source investigation: automatic client display management

- Inspected the released `spice-vdagent` **0.23.0** source:
  `src/vdagent/display.c:vdagent_display_send_daemon_guest_res()` reports
  guest resolutions to the daemon. However,
  `src/vdagentd/vdagentd.c:do_agent_xorg_resolution()` explicitly ignores
  messages whose total width and height are both zero. A simple direct
  forwarding of a zero-size guest resolution is therefore not established.
- `check_xorg_resolution()` opens the guest VirtIO agent channel when an
  active session agent has reported usable screen information. Removing
  the session agent can thus also disable the client-side agent connection;
  our counterchecks do not uniquely identify a bug inside the session agent.
- Host `pkg-config --modversion spice-client-gtk-3.0` reports **0.43**.
  Inspected Nixpkgs' `spice-gtk` 0.43 source:
  `src/spice-widget.c:update_ready()` updates the display's enabled state
  from its readiness when `resize-guest` is enabled.
  `src/channel-main.c:spice_main_channel_send_monitor_config()` emits
  zero-filled entries for disabled displays when sparse monitor
  configuration is supported, and requires an agent connection.
- Current upstream Virt-Manager's `SpiceViewer._set_resizeguest()` sets
  precisely this `resize-guest` property. QEMU's current upstream
  `interface_client_monitors_config()` copies incoming client monitor
  geometry into QXL ROM and raises the client-monitor interrupt on changes.
  These two upstream inspections are not verification of the exact host
  builds or the actual messages exchanged during our reproduction.
- **Concrete hypothesis:** display shutdown changes client readiness;
  automatic guest resizing treats that as a disabled monitor and sends a
  zero-size configuration. QXL then disconnects the output, preventing
  normal DPMS wake. The session agent enables the communication path rather
  than necessarily generating the bad configuration itself.
- **Next targeted check:** retain both guest agents and QXL, but disable
  automatic guest resizing in the Virt-Manager console before shutdown.
  This is distinct from display scaling. A successful repeated wake would
  support a narrower workaround preserving guest clipboard integration.
  Client debug logs are still needed to prove the outgoing configuration.

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
