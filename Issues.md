# Known issues

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
