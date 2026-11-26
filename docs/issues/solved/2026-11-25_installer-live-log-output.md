# NixOS installation output is missing from Calamares Toggle log

- Status: Solved; Full ISO live logging confirmed by the user
- Recorded: 2026-11-25
- Resolved: 2026-11-25

## Problem and investigation

Inherited subprocess stdout/stderr did not make `nixos-install` output
visible in Calamares' UI log. `a9ebb56` switched to its public host process
interface, but supplied no output callback. That logged command startup,
not the running installation's output.

## Solution and verification

`42f50f3` passes the public Calamares debug logger as the output callback.
Streaming remains limited to installation commands without secret input or
configuration. Timeout-free execution and existing failure handling remain.
Tests check callback wiring and live output forwarding. `9cf72b2` records
user-confirmed Toggle log behavior with the new Full ISO.

Original Nix output is not sanitized; inspect logs before sharing.

## Evidence

- `a9ebb56`, `42f50f3`, `9cf72b2`.
- See also [file-write output exposure](2026-11-26_installer-echoes-file-contents.md).
