---
status: solved
status-description: "Unit-tested; VM failure-diagnostics check confirmed by the user"
---

# Installer errors obscure the failing phase and original Nix error

## Problem

Generic partition/password advice did not identify the actual failure.
Reporting `unshare failed` also misattributed the wrapper's exit status:
it did not distinguish a wrapper failure from a failing `nixos-install` child.
Failures occur after partitioning, so retry advice must not imply a harmless
restart or a complete installation.

## Correction

`c08c642` adds validation reasons, command exit codes and OS errno.
`4b6ad8c` tracks mount validation, configuration, user setup, system install
and model copying separately; names the system-installation invocation
without guessing its cause; and includes a journal command scoped to the
adapter start time. Install-stage errors warn that the target has already
been partitioned, including repeated preflight failures.

Commands are logged by program name, without arguments, passwords or hashes.
Original subprocess output is retained, not heuristically sanitized or
automatically uploaded. Inspect it before sharing and find the first error.

## Verification

Adapter tests cover error details and sensitive-data handling. Full ISO live
logging was later confirmed, but this does not prove failure-dialog behavior.

On 2026-11-26, the user confirmed the Desktop VM failure-diagnostics check
as successful. The requested check covered the failing phase, concrete error,
journal command with time filter and warning about prior partitioning.
This supplies the previously missing runtime confirmation. The exact induced
failure and its output were not supplied; this does not establish individual
runtime coverage of every failure path.

## Evidence

- `c08c642`, `4b6ad8c`, `42f50f3`, current `TODO.md`.
- User confirmation of VM checklist item 6 on 2026-11-26.
