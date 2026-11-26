---
status: open
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

On 2026-11-26 the same symptom was reproduced on the Bosgame M5 hardware, so
it is not VM- or SPICE-specific; see
[no image after automatic screen shutdown on the M5](2026-11-26_m5-black-screen-after-idle.md).

## Next verification

Automatic screen shutdown was changed to `Never` in the guest's Plasma
power settings; automatic screen locking was left unchanged. Leave the
guest idle for at least ten minutes and check whether the lock screen
appears and can be unlocked normally. This countercheck is pending.

## Evidence

- `94287c1`: records the observation, journal evidence and pending check.
- Former root `Issues.md`.
