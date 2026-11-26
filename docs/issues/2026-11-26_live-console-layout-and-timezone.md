---
status: verification-pending
status-description: "Fixed in configuration; new ISO runtime check pending"
---

# Live ISO console layout and time zone are not neutral defaults

## Problem and correction

The live ISO needed a US console layout and UTC independently of the target
system's preferences and the settings selected in Calamares.
`4bbfa2f` sets `console.keyMap = "us"` and `time.timeZone = "UTC"` for the live
environment only. Target profiles and installation choices are unchanged.

## Verification

Assertions cover both settings for every live profile. Evaluation and
formatting passed. The commit explicitly records that no new ISO was built;
booted-media verification of the correction remains unrecorded.

## Evidence

- `4bbfa2f`, `build/live.nix`, `tests/profiles.nix`.
