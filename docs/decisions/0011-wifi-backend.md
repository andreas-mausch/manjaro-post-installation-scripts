---
status: accepted
date: 2026-11-26
deciders: [neonew]
supersedes: []
superseded-by: []
---

# 0011: Wi-Fi backend

## Context

The fresh setup needs interactive networking in KDE and in the live installer,
including Wi-Fi on the Bosgame M5. NetworkManager provides connection management,
desktop integration, VPN support and command-line administration. Its Wi-Fi
authentication backend is a separate choice.

The live ISO previously disabled the default wpa_supplicant backend by mistake;
the [Wi-Fi investigation](../issues/2026-11-26_live-wifi-backend-unavailable.md)
records that failure. It is not evidence that wpa_supplicant is inherently unreliable.

neonew explicitly requested iwd for the new setup on 2026-11-26. This is an
architectural choice before hardware comparison, not a measured performance win.

## Decision

Use NetworkManager with iwd as the Wi-Fi backend in every live ISO and installed
profile, through the shared `modules/networking.nix` module. Disable wpa_supplicant
and do not explicitly include it in system packages. NetworkManager owns IP and DNS;
disable iwd's independent network configuration to avoid competing managers.

## Consequences

- **Positive:** One shared backend policy for live and target systems; KDE and
  NetworkManager tooling remain available. iwd is a modern, focused Wi-Fi daemon.
- **Negative:** Existing wpa_supplicant-specific configuration is not reused directly.
  The pinned Nixpkgs option describes NetworkManager's iwd backend as experimental.
- **Risks / neutral:** M5 discovery, connection, reconnection and suspend/resume
  still need testing. Modern WPA2/WPA3 use is the intended scenario, not proof that
  every access point or authentication method works. Enterprise requirements need
  explicit validation. No lower overhead, higher throughput or improved stability
  has been measured in this project.
- Disabling wpa_supplicant services is not a claim that no unrelated package can
  ever reference it transitively; check actual closures if that becomes a requirement.

## Options considered

| Option                          | Verdict      | When it is appropriate                                             |
| ------------------------------- | ------------ | ------------------------------------------------------------------ |
| NetworkManager with iwd          | ✅           | Fresh setup, focused backend, modern WPA2/WPA3; validate integration |
| NetworkManager with supplicant   | Not selected | Existing setups, legacy devices or tested enterprise configurations |
| Standalone iwd                  | Not selected | Minimal systems without NetworkManager; not our KDE/live workflow   |

iwd is worth considering for lean fresh installations, including Arch, Debian
and Fedora, but distribution names alone do not establish a technical advantage.
wpa_supplicant remains a reasonable choice when preserving an existing setup,
extensive configuration or tested enterprise/older-system compatibility matters.
iwd also supports enterprise authentication; the distinction is validation and
migration risk, not a blanket assertion that enterprise Wi-Fi requires supplicant.

## References

- User decision on 2026-11-26.
- Pinned Nixpkgs `nixos/modules/services/networking/networkmanager.nix`.
- [iwd documentation](https://iwd.wiki.kernel.org/).
- [NetworkManager configuration](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html).
