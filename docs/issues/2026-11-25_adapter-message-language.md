# Adapter diagnostics remain German when the Calamares UI language changes

- Status: Fixed and catalog-tested; runtime language-switch check unrecorded
- Recorded: 2026-11-25

## Problem and solution

Hardcoded German messages did not follow the current UI language.
`8503d52` replaces them with English source strings and a German gettext
catalog, resolving the current Calamares UI language on every translation
call rather than caching it before the user changes language.

## Verification

At that commit all sixteen adapter tests passed; the catalog compiled and
covered all 31 then-existing messages. English fallback behavior is tested.
Later commits add translations, but the inspected history does not establish
a dedicated runtime language-switch test for the complete current catalog.

## Evidence

- `8503d52`, `modules/installer/calamares/locale/de.po`.
