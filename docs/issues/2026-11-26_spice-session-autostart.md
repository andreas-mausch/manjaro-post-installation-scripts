---
status: workaround
status-description: >-
  Validated user-local autostart workaround; removal requires an upstream fix
  ([Nixpkgs #239490](https://github.com/NixOS/nixpkgs/issues/239490));
  packaged correction awaits ISO verification.
---

# SPICE session agent does not start automatically

## Problem and diagnosis

In the Desktop Plasma VM, `spice-vdagentd` ran but the session agent did not
start. XDG autostart was enabled and its systemd target active. The desktop
entry had a valid executable Nix Store `Exec` path, but contained
`X-systemd-skip=true`. Debug output from `systemd-xdg-autostart-generator`
confirmed: `not generating unit, marked as skipped by generator.`

## Solution and verification

Removing only `X-systemd-skip` in a user-local desktop entry restored startup
after a fresh login. Both agents ran and the generated SPICE autostart user
service was `active (running)`. `X-GNOME-Autostart-Phase` stayed unchanged.

`9fff037` applies this correction in `modules/spice.nix`, preserves the other
upstream settings, and bundles the corrected entry for offline installation.
It uses the standard XDG generator rather than adding a custom user service.
The fresh-login evidence covers the user-local workaround; a new ISO test
of the packaged correction is not recorded in the inspected history.

## References

- `ad7b1dc`: confirmed cause and fresh-login test.
- `9fff037`: repository fix.
- [Nixpkgs issue #239490](https://github.com/NixOS/nixpkgs/issues/239490#issuecomment-1795843923)
- [Nixpkgs PR #266080](https://github.com/NixOS/nixpkgs/pull/266080): proposed
  user-service integration, unavailable in the pinned revision at diagnosis.
- [Separate Wayland clipboard issue](2026-11-26_spice-wayland-clipboard.md).
