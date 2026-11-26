---
status: open
status-description: "Upstream limitation, no validated local fix; current upstream status not rechecked"
---

# SPICE clipboard only works from host to guest under Plasma/Wayland

## Observation

Confirmed in the Desktop VM with spice-vdagent 0.23.0: starting
`spice-vdagent -x` manually enables host → guest copying only. Guest → host
still fails; no clipboard restriction was found in Virt-Manager.

This is separate from the [session-agent autostart problem](2026-11-26_spice-session-autostart.md).
Restoring autostart does not establish bidirectional clipboard support.

## Investigation and remaining work

The directional limitation matches
[Red Hat bug 2016563](https://bugzilla.redhat.com/show_bug.cgi?id=2016563).
As recorded in November 2026, the
[Wayland support proposal](https://gitlab.freedesktop.org/spice/linux/vd_agent/-/merge_requests/57)
was awaiting upstream review/merge. This is a historical status, not an
automatically refreshed upstream check. No fix or X11 workaround has been
validated in this project.

## Evidence

- `8833784`, `ad7b1dc`: document the observed directional limitation.
- Former root `Issues.md`.
