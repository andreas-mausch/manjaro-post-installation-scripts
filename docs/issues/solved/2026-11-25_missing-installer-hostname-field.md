# Calamares hides the hostname field and the adapter substitutes a default

- Status: Fixed; adapter regression tests added
- Recorded: 2026-11-25
- Resolved: 2026-11-25

## Problem

The Calamares users configuration did not expose its native hostname field.
The adapter silently substituted a fallback instead of requiring the value
chosen by the user.

## Solution and verification

`5cecccc` selects `EtcFile` so Calamares displays and validates the hostname
field. The adapter requires a supplied hostname and reports a translated
integration error for missing or blank values. Tests cover both cases.
Legacy installation.json identity handling was removed in favor of the
editable `configuration.nix`. A runtime UI check specifically after this
commit is not recorded; earlier Full GUI confirmation predates it.

## Evidence

- `5cecccc`; preceding host-configuration work in `48b9e5d`.
