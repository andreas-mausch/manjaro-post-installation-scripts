# Model copying obscures progress and couples retry to system installation

- Status: Solved within the current installer scope; Full behavior confirmed
- Recorded: 2026-11-25
- Resolved: 2026-11-25

## Problem

Copying roughly 115 GB in the same job as system deployment obscured which
stage was running. A copy failure needed distinct advice so users would not
erase a successfully installed system simply to retry copying. Coarse
progress did not show the ongoing large-file transfer.

## Solution and verification

`9184204` separates installation and model copying into native Calamares job
instances sharing the adapter. Copying is skipped when weights are not
selected and fails with stage-specific messages when sources or mounts are
invalid. `19f6455` logs payload size, each filename and final target path,
and tracks destination bytes during each copy. Existing files are reset to
avoid inflated retry progress; completion waits for copying and permissions.

`9cf72b2` and `3562679` record user-confirmed Full progress, separate-job
behavior and no-copy handling. Progress is not a checksum or durable-write
guarantee. Build-time pinned checksums plus successful copying are the
accepted integrity strategy; a target checksum pass was deliberately omitted.

There is still no interactive model-only retry mode. Use the manual recovery
instructions in the root README without repartitioning the existing system.

## Evidence

- `9184204`, `19f6455`, `9cf72b2`, `3562679`.
