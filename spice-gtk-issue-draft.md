# QXL/Wayland: display shutdown causes persistent connector loss with guest auto-resize enabled

Draft for the spice-gtk issue tracker. Not submitted. Investigation paused:
the local issue was closed with VirtIO-GPU as the accepted workaround, without
a confirmed QXL root-cause fix.

## Summary

In a NixOS Plasma/Wayland guest using QXL, automatic display shutdown results
in a black screen that does not recover on keyboard or mouse input.

Disabling automatic guest resizing in Virt-Manager allows the display to wake
successfully while both guest SPICE agents remain running.

## Environment

- Host OS: **to be added**
- Host: QEMU 11.1.3, libvirt 12.9.0, spice-gtk 0.43
- Viewer: Virt-Manager (**version to be added**)
- Guest: NixOS, Plasma/Wayland, Linux 7.3.5
- Plasma/KWin version: **to be added for the tested installed guest**
- Guest agent: spice-vdagent 0.23.0
- Video: QXL, `max_outputs=1`
- Display transport: SPICE

## Steps to reproduce

1. Boot the QXL guest and log into Plasma/Wayland.
2. Ensure both `spice-vdagentd` and the user-session `spice-vdagent` are running.
3. Enable automatic guest resizing in Virt-Manager.
4. Disable dimming and system suspend; set display shutdown to one minute.
5. Allow the display to shut down.
6. Attempt to wake it using keyboard or mouse input.

## Expected result

The display wakes and remains connected. Display power-off should not be
interpreted as monitor removal.

## Actual result

The display remains black. SSH continues to work, but all guest DRM connectors
report `disconnected`.

The kernel journal, with DRM debugging enabled using
`echo 0x06 | sudo tee /sys/module/drm/parameters/debug`, shows:

```text
21:24:11 drm_atomic_helper_commit_crtc_disable: inactive head 0, skip (disable)
21:24:11 qxl_crtc_atomic_flush: no primary surface, skip (flush)
21:24:12 qxl_display_read_client_monitors_config: read 0x0+0+0
21:24:12 Virtual-1: status updated from connected to disconnected
21:24:12 Virtual-1: generating connector hotplug event
```

In an earlier reproduction, reconnecting or resizing the viewer and restarting
the guest display manager did not restore the connectors.

## Counterchecks

| Configuration                                                 | Result                                        |
| ------------------------------------------------------------- | --------------------------------------------- |
| QXL, both guest agents stopped                                | Two successful shutdown/wake cycles           |
| QXL, both agents re-enabled without reboot                     | Black screen and connector loss reproduced    |
| QXL, root daemon running, session agent stopped                | Successful wake                               |
| QXL, both agents running, automatic guest resizing disabled    | Successful wake                               |
| VirtIO-GPU instead of QXL, SPICE retained                       | Successful wake, including automatic locking  |

The auto-resize-disabled result covers two user-confirmed successful cycles.

## Possible mechanism — not yet confirmed

In spice-gtk 0.43, `update_ready()` in `src/spice-widget.c` updates the display's
enabled state based on readiness when `resize-guest` is enabled.

`spice_main_channel_send_monitor_config()` in `src/channel-main.c` produces
zero-filled entries for disabled displays when sparse monitor configuration
is supported.

Could display shutdown therefore cause the client to send a disabled/zero-size
monitor configuration, which QXL interprets as disconnection and cannot recover
from through normal DPMS wake?

The session-agent counterchecks do not necessarily indicate a bug within the
session agent: its presence also enables the guest agent communication path.
In spice-vdagent 0.23.0, the daemon ignores guest-resolution reports whose total
width and height are both zero, so direct forwarding of those reports is not
established.

We have not yet captured the outgoing client message, so the origin of the
zero-size configuration remains a hypothesis.

## Related report

[virt-manager/virt-manager#924](https://github.com/virt-manager/virt-manager/issues/924)
also concerns QXL/Wayland displays remaining blank, but involves reconnecting
the viewer while the display is off. It may be related, but the reproduction
differs.
