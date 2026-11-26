# Variant ISO filenames ignore image.fileName

- Status: Solved; Desktop ISO rebuilt with corrected name
- Recorded: 2026-11-25
- Resolved: 2026-11-25

## Problem and solution

The pinned ISO builder uses `image.baseName` directly when constructing
its output; setting `image.fileName` did not provide the intended variant
names. `a96b9bb` sets the base name so outputs are `nixos-<variant>.iso` under
`result/iso/`.

## Verification

Checks assert both the base name and resulting filename for each profile.
The Desktop ISO was rebuilt successfully with its corrected name. This is
filename/build evidence, not independent installation evidence for every ISO.

## Evidence

- `a96b9bb`, `build/live.nix`, `tests/profiles.nix`.
