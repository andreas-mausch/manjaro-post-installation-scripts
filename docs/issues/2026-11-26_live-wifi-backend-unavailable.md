---
status: verification-pending
status-description: >-
  Removed the live override disabling NetworkManager's wpa_supplicant backend;
  rebuilt ISO Wi-Fi discovery and connection still need hardware verification.
---

# Live Wi-Fi is unavailable because the supplicant backend cannot start

## Observation

On 2026-11-26, the user booted the Desktop live ISO on the Bosgame M5.
No Wi-Fi networks appeared. Wi-Fi was enabled and rfkill reported no block.
NetworkManager recognized `wlp195s0` but reported state 20 (`unavailable`)
and reason 2 (`device is now managed`). The user identified the `mt7925e`
driver and a firmware patch load, without an observed firmware error.
The NetworkManager journal reported failure to D-Bus activate wpa_supplicant.

## Cause and correction

`build/live.nix` forced `networking.wireless.enable = false` while enabling
NetworkManager. In the pinned Nixpkgs NetworkManager module, the default
wpa_supplicant backend requires `networking.wireless.enable = true`, with
`dbusControlled = true` and `autoDetectInterfaces = false`. The forced override
disabled the backend needed for NetworkManager-managed Wi-Fi, not merely an
independent competing wireless manager.

Remove that override and let NetworkManager configure its backend. Profile
assertions now require NetworkManager and its D-Bus-controlled wireless backend
for every live profile. No MediaTek driver or firmware workaround is introduced.

## Remaining verification

Boot a rebuilt Desktop ISO on the M5. Confirm that `wlp195s0` is available,
Wi-Fi networks are listed, and a connection succeeds without the D-Bus
activation error. Evaluation and profile tests do not replace this hardware check.

## Evidence

- User-reported device state, rfkill/radio checks and NetworkManager error on 2026-11-26.
- Pinned Nixpkgs `nixos/modules/services/networking/networkmanager.nix` backend configuration.
- `build/live.nix`, `tests/profiles.nix`.
