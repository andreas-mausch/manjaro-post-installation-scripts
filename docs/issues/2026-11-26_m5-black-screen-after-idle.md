---
status: open
---

# No image after automatic screen shutdown on the Bosgame M5

## Observation

On the Bosgame M5 with the Plasma/Wayland desktop, the display turned off
after 10 minutes of idle and no image returned afterwards. This is the same
symptom previously observed only in the Desktop VM (see
[black screen after idle in the VM](2026-11-26_virtmanager-black-screen.md)).

The reproduction on real hardware shows the failure is not specific to the
VM, QXL or SPICE. A shared cause in Plasma/Wayland display power management,
possibly interacting with the GPU driver, is plausible but unconfirmed.
Mouse/keyboard activity and Ctrl+Alt+F3 produced no response and no image,
matching the VM observation where Ctrl+Alt+F3 also did not recover. Whether
the system itself stayed running (beyond the display) is not established.

## Next verification

- SSH into the M5 after the blank to determine whether the system is still
  running and only the display path failed, or whether input and session
  handling are also stuck.
- Check the journal around the blanking event on the M5 for DRM/KMS,
  lock screen and PowerDevil messages; compare with the VM journal
  (`There are no outputs - creating placeholder screen`).
- Test whether disabling automatic screen shutdown in Plasma prevents the
  failure on the M5, mirroring the pending VM countercheck.

## Evidence

- 2026-11-26: User report confirming the failure on the Bosgame M5 after
  10 minutes of idle, ruling out a purely VM-specific cause.
- 2026-11-26: User report confirming that neither mouse/keyboard activity
  nor Ctrl+Alt+F3 restored an image or showed any response.
