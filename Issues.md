# Known issues

## SPICE clipboard under Plasma/Wayland

Confirmed in the Desktop VM with spice-vdagent 0.23.0 (2026-11-26):

- The system daemon runs, but the session agent does not start automatically.
  In the installed Plasma guest, XDG autostart is enabled and its systemd
  target is active. The installed desktop entry has a valid, executable
  Nix Store `Exec` path, but contains `X-systemd-skip=true`. Running the
  guest's `systemd-xdg-autostart-generator` with debug logging confirms:
  `not generating unit, marked as skipped by generator.`
  Removing only `X-systemd-skip` in a user-local copy of the desktop entry
  restores startup after a fresh login: both `spice-vdagentd` and
  `spice-vdagent` run, and the generated SPICE autostart user service is
  `active (running)`. `X-GNOME-Autostart-Phase` remains unchanged.
  The user-local override is a validated workaround; no repository fix
  has been implemented.
  The open
  [Nixpkgs issue #239490](https://github.com/NixOS/nixpkgs/issues/239490#issuecomment-1795843923)
  reports the same need to start `spice-vdagent` manually despite enabled,
  running services, although the issue focuses on screen resizing.
  The open, unmerged [Nixpkgs PR #266080](https://github.com/NixOS/nixpkgs/pull/266080)
  proposes a separate `services.spice-vdagent.enable` option to start the
  session agent as a systemd user service instead of relying on XDG autostart.
  This option is not available in our pinned Nixpkgs revision. The PR states
  that upstream has shipped a similar user service since version 0.22.0;
  its integration into NixOS remains to be investigated. This proposal
  concerns session-agent startup, not the separate Wayland clipboard limitation.
- Starting `spice-vdagent -x` manually enables host → guest copying only.
  Guest → host still fails; no clipboard restriction was found in Virt-Manager.

The directional limitation matches
[Red Hat bug 2016563](https://bugzilla.redhat.com/show_bug.cgi?id=2016563).
As of November 2026, the
[Wayland support proposal](https://gitlab.freedesktop.org/spice/linux/vd_agent/-/merge_requests/57)
is awaiting upstream review/merge. No fix or X11 workaround has been validated
here. The missing autostart is a separate issue.
