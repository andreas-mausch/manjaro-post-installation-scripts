---
status: solved
status-description: "Graphical unlock and clean login handover confirmed in the encrypted VirtIO GPU VM"
---

# Plymouth text prompt and delayed boot in encrypted UEFI VM

- Resolved: 2026-11-27

## Problem

After updating the existing encrypted Desktop VM to Plymouth configuration
from `506a185`, the LUKS prompt remains textual instead of showing the spinner
theme. After unlocking, the display appears stuck at `Starting Switch Root`.
The user reports that pressing Escape allows the boot to continue visibly.
The desktop eventually starts. Whether Escape unblocks boot or only changes
the visible display has not been established.

## Evidence

- Screenshots confirm successful LUKS unlock and root filesystem mounting.
- Kernel logs identify the virtual graphics adapter as `virtio_gpu`.
- `plymouth-read-write.service` starts at 15:24:43 and finishes at 15:25:36,
  a 53-second delay. The Plymouth quit and quit-wait services start and finish
  at 15:25:37 without a comparable delay.
- The generated hardware configuration imports `profiles/qemu-guest.nix`.
  Its explicit initrd module list includes `virtio_pci` but not `virtio_gpu`;
  `boot.initrd.kernelModules` is empty. This does not inventory modules added
  by imports or prove that a missing early driver causes the delay.
- Profile checks and the Desktop initrd build passed before runtime testing;
  these checks did not establish graphical rendering or a working handover.

## Next diagnostic test

Add the following inside the existing module in the VM's
`/etc/nixos/configuration.nix`, rebuild and reboot:

```nix
boot.initrd.kernelModules = [ "virtio_gpu" ];
```

Check whether the graphical LUKS prompt appears and boot completes without
Escape. Early GPU loading is a hypothesis, not a confirmed fix. No universal
GPU module list or Plymouth service workaround has been added to the project.

## Follow-up

The user reports that the next boot completed without pressing Escape, but
Plymouth still showed no spinner. This does not resolve the graphical-display
problem or establish the cause of the earlier delay. No new timing logs or
confirmation of the effective initrd module configuration were supplied.

Subsequent screenshots confirm `virtio_gpu` loading before Plymouth and
`plymouth-read-write.service` completing without the earlier 53-second delay.
SSH debugging then identified the reason for the remaining text display:
`serial consoles detected, managing them with details forced`.
The suggested `IgnoreSerialConsoles=true` daemon setting was ineffective.
The installed binary contains the supported kernel parameter
`plymouth.ignore-serial-consoles`; adding that parameter in the VM restored
the graphical LUKS prompt, with the NixOS logo and German keyboard indicator.

The user confirms the spinner and subsequent graphical login without Escape.
However, a brief text-log display appears between the spinner and login.
The graphical prompt is therefore working, but the visual handover remains
unsatisfactory. `plymouth.debug` was still active during this test; it is being
removed for a comparison boot before changing service handover behavior.
These diagnostic configuration changes are local to the VM, not yet a shared
project fix. The cause of the initial delay is not independently established.

## Resolution

After removing `plymouth.debug`, the user confirmed a clean transition from
spinner to graphical login without text flash or Escape. The successful VM
configuration retains early `virtio_gpu` loading and the kernel parameter
`plymouth.ignore-serial-consoles`. The latter is now included in the shared
base profile, with a profile assertion. The GPU module remains host-local.
The ineffective `IgnoreSerialConsoles=true` setting is removed from the VM.
The serial console itself remains available; only Plymouth ignores it.

This resolves the reported VM behavior. Hardware boots and an explicit
incorrect-password/text-fallback test were not separately established.

## Clean installation and retained splash

A fresh encrypted Desktop VM installation from the personalized `d2284ad`
ISO confirmed graphical boot without local early-GPU overrides. Kernel logs
show `virtio_gpu` loading early. The user nevertheless observed a brief,
likely textual flicker before the login screen. Plymouth quit at 15:49:50;
the SDDM greeter added its view at 15:49:53. This supports a visible handover
gap, but does not prove which content appeared during it.

The VM then tested `plymouth quit --retain-splash` in the existing quit unit,
without sleeps, parallel startup or replacing SDDM's service. The user judged
the result good enough, with a possible remaining mini-flicker. This override
is now shared by the Desktop-derived profiles, conditional on Plymouth being
enabled. The base/server profile retains native quit behavior.

This preserves SDDM's ordering after Plymouth quit and uses Plymouth's native
retained final frame. It is not a coordinated compositor handover or a promise
of flicker-free output on all hardware. Bosgame validation remains pending.
