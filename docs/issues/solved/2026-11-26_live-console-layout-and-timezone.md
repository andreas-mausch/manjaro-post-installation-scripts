---
status: solved
status-description: "UTC and expected US Y/Z behavior confirmed in the booted Desktop VM"
---

# Live ISO console layout and time zone are not neutral defaults

## Problem and correction

The live ISO needed a US console layout and UTC independently of the target
system's preferences and the settings selected in Calamares.
`4bbfa2f` sets `console.keyMap = "us"` and `time.timeZone = "UTC"` for the live
environment only. Target profiles and installation choices are unchanged.

## Verification

Assertions cover both settings for every live profile. Evaluation and
formatting passed. The implementation commit did not build a new ISO.

On 2026-11-26, the user tested the newly built Desktop ISO in the VM.
A supplied screenshot shows `timedatectl` reporting `Time zone: UTC` and
`localectl status` reporting `X11 Layout: us`, but `VC Keymap: (unset)`.
The latter does not establish the active console layout. After being asked
to check Y/Z behavior on a text console, the user confirmed that the keys
behave as expected for the US layout. No separate special-character check
was reported.

Runtime evidence covers the Desktop live ISO; other live profiles remain
covered by configuration assertions rather than individual boot tests.

## Evidence

- `4bbfa2f`, `build/live.nix`, `tests/profiles.nix`.
- User-provided Desktop VM screenshot and Y/Z behavior confirmation on 2026-11-26.
