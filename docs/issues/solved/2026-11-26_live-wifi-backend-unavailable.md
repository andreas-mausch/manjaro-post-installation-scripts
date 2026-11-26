---
status: solved
status-description: >-
  Wi-Fi discovery, connection and web access confirmed on the M5 with the
  rebuilt Desktop live ISO using NetworkManager and iwd.
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

The initial correction removed that override and let NetworkManager configure
its backend. Its profile assertions required the D-Bus-controlled wireless
backend. No MediaTek driver or firmware workaround was introduced.

## Backend decision and verification

After the initial correction, neonew selected iwd as the backend for both live
and installed systems; see [ADR 0011](../../decisions/0011-wifi-backend.md).
The current shared module intentionally disables wpa_supplicant while enabling
iwd through NetworkManager. Regression assertions cover this new backend policy
instead of requiring the formerly selected supplicant backend.

On 2026-11-26, the user confirmed that the rebuilt Desktop live ISO lists
Wi-Fi networks on the M5, connects successfully and can open a webpage.
This verifies discovery, authentication and usable network access for the tested
hardware/network combination. No post-fix journal was supplied, and reconnect,
suspend/resume, enterprise networks and installed-target behavior remain outside
this confirmation. The ISO predates the pending firmware/MBROLA size reductions.

## Evidence

- User-reported device state, rfkill/radio checks and NetworkManager error on 2026-11-26.
- Pinned Nixpkgs `nixos/modules/services/networking/networkmanager.nix` backend configuration.
- `build/live.nix`, `tests/profiles.nix`.
- `204af73`: shared NetworkManager/iwd backend policy.
- User-confirmed M5 live Wi-Fi discovery, connection and web access on 2026-11-26.
