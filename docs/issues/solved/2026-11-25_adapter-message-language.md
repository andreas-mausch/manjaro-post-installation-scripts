---
status: solved
status-description: "Catalog-tested; German adapter messages confirmed after language selection in the Desktop VM"
---

# Adapter diagnostics remain German when the Calamares UI language changes

## Problem and solution

Hardcoded German messages did not follow the current UI language.
`8503d52` replaces them with English source strings and a German gettext
catalog, resolving the current Calamares UI language on every translation
call rather than caching it before the user changes language.

## Verification

At that commit all sixteen adapter tests passed; the catalog compiled and
covered all 31 then-existing messages. English fallback behavior is tested.
Later commits add translations.

On 2026-11-26, the user confirmed that the adapter's own phase and progress
messages appeared in German after selecting German in Calamares in the
Desktop VM. This supplies the previously missing runtime language-selection
evidence; it does not claim that every catalog entry was individually observed.

Calamares strings such as `Toggle log` and `Starting job`, and Nix output such
as `copying path`, remained in English. These originate outside the adapter
and are not translated by its gettext catalog; this is expected behavior,
not a failure of the adapter language selection.

## Evidence

- `8503d52`, `modules/installer/calamares/locale/de.po`.
- User-confirmed German adapter phase and progress messages in the Desktop
  VM on 2026-11-26, with external Calamares/Nix output remaining in English.
