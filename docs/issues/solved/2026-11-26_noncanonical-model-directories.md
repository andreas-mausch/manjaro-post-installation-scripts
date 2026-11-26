# Model directory options accept unsafe or noncanonical paths

- Status: Fixed; evaluation tests cover rejected paths
- Recorded: 2026-11-26
- Resolved: 2026-11-26

## Problem

Model paths feed service arguments and tmpfiles rules. Parent-prefix checks
alone are not reliable when input contains dot segments or other
noncanonical spellings. The root and both nested directory options needed
the same validation contract.

## Solution and verification

`1633bff` introduces a shared checked type using `lib.path.subpath` validation
and normalization. Relative paths, root, dot segments, empty segments,
trailing separators and parent traversal are rejected rather than rewritten.
Each nested directory must remain under its canonical parent. Evaluation
tests exercise invalid values for all three options.

## Evidence

- `1633bff`.
- `modules/generative-ai/default.nix`, `tests/test_profiles.py`.
