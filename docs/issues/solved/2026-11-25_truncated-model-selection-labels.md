---
status: "Fixed; later Full model-selection UI confirmed"
---

# Calamares truncates the model-selection step title
- Resolved: 2026-11-25

## Problem and solution

Long model-selection labels were truncated in Calamares. `c1af652` uses the
short step title `Model Weights`, adds its German translation and removes
the installation verb from the option label while retaining model and
quantization identity.

## Verification

`9cf72b2` records user-confirmed model selection with the new Full ISO.
It does not explicitly report a separate truncation test for every language
or screen size.

## Evidence

- `c1af652`, `9cf72b2`.
