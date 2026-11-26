---
status: open
status-description: >-
  Installed VM switches to a low resolution before login; the KDE session
  returns to the full viewer size. Cause and exact resolutions unconfirmed.
---

# Installed VM uses a low resolution before login

## Observation

On 2026-11-26, the user reported the following sequence after installation:

1. The early Linux kernel console initially uses the expected display dimensions.
2. The display then shrinks to approximately 800×600; this is an estimate, not a measured resolution.
3. The SDDM login screen remains at the smaller resolution.
4. After login, the KDE session returns to the full Virt-Manager viewer dimensions.

The user suspects SPICE supplies the initial and post-login sizing. This is not yet verified;
the observation alone does not identify which component changes the mode or at which exact boot stage.

## Investigation

Early console graphics, the SDDM greeter and the user's KDE session may select modes independently.
The user-session SPICE agent does not by itself establish resize support in the greeter.
This is distinct from the [session-agent autostart issue](2026-11-26_spice-session-autostart.md)
and the [black screen after idle](2026-11-26_virtmanager-black-screen.md).

## Next verification

- Record the VM video device, greeter display backend and exact resolutions before and after login.
- Identify whether the low-resolution transition occurs before SDDM starts or when the greeter takes over.
- Inspect the boot journal for SDDM and graphics mode changes; test whether resizing the viewer affects the greeter.
- Evaluate supported greeter display settings after establishing the cause; do not assume a SPICE failure or
  introduce a fixed resolution that would affect real hardware.

## Evidence

- User report on 2026-11-26 after installation; no screenshot, mode output or diagnostic journal supplied yet.
