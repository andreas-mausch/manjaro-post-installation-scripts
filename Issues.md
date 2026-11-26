# Known issues

## Black screen after idle in the Plasma/Wayland VM

Observed in the existing QXL/SPICE Desktop VM (2026-11-26): the display
turned black after idle and did not recover after reconnecting Virt-Manager
or sending Ctrl+Alt+F3. The guest journal shows system services continuing
to run, so a complete guest freeze is not established.

The previous boot's journal shows the lock screen starting at 00:55:27,
followed by a DRM hotplug event at 00:56:28 and messages from the lock screen
and PowerDevil: `There are no outputs - creating placeholder screen`.
No kernel entries were recorded in the inspected 00:55–00:57 interval.
The cause and any relation to SPICE remain unconfirmed.

Next check: automatic screen shutdown was changed to `Never` in the guest's
Plasma power settings; automatic screen locking was left unchanged.
Leave the guest idle for at least ten minutes and check whether the lock
screen appears and can be unlocked normally. This countercheck is pending.

## SPICE clipboard under Plasma/Wayland

Confirmed in the Desktop VM with spice-vdagent 0.23.0 (2026-11-26):

- Starting `spice-vdagent -x` manually enables host → guest copying only.
  Guest → host still fails; no clipboard restriction was found in Virt-Manager.

The directional limitation matches
[Red Hat bug 2016563](https://bugzilla.redhat.com/show_bug.cgi?id=2016563).
As of November 2026, the
[Wayland support proposal](https://gitlab.freedesktop.org/spice/linux/vd_agent/-/merge_requests/57)
is awaiting upstream review/merge. No fix or X11 workaround has been validated
here.
