---
status: accepted
date: 2026-11-27
deciders: [neonew]
supersedes: []
superseded-by: []
---

# 0013: Time synchronization

## Context

Live and installed profiles use NetworkManager. The user requires automatic
time synchronization exclusively from DHCP-provided NTP servers, for IPv4 and
IPv6, with no static sources, public pools or fallbacks. Without DHCP NTP
information the clock must not synchronize externally. No NTP server or
network administration listener may be provided.

Host inspection found router NTP addresses in both received options:
DHCPv4 `ntp_servers` and DHCPv6 `dhcp6_ntp_servers`. Libvirt's default NAT
network did not advertise NTP sources initially.

## Decision

Use systemd-timesyncd with a focused NetworkManager dispatcher following the
ArchWiki drop-in approach. Explicitly set `NTP=` and `FallbackNTP=` to empty
lists in the shared base configuration and clear `networking.timeServers`.
Do not run Chrony or an NTP server and do not open inbound NTP firewall ports.

On connection and DHCP changes, read only NetworkManager's received IPv4/IPv6
NTP options and atomically maintain per-interface
drop-ins in `/run/systemd/timesyncd.conf.d`. Remove a drop-in on disconnect or
when the lease no longer provides sources. Restart timesyncd only when source
configuration changes. Refresh already active connections on activation.
Serialize refresh and dispatcher updates. Do not derive NTP addresses from
gateway or DNS options. Runtime files must not survive reboot.

timesyncd is a client: no network server listeners are allowed. Outgoing
UDP client sockets are necessary and are not NTP-serving sockets.

Configure DHCP NTP advertisements separately in the local libvirt network,
using the router sources actually received on the host. Advertising a source
does not start a time server. Those local addresses do not belong in shared
timesyncd configuration.

This ADR was amended before its first commit at the user's request. The
intermediate Chrony trial was not activated. Chrony's NixOS NetworkManager
dispatcher handles connectivity but does not import DHCP NTP sources, so it
offers no integration advantage for this requirement.

## Consequences

- **Positive:** Native client, explicit DHCP-only policy, both address families,
  no hidden fallback and no NTP-serving role.
- **Negative:** A small dispatcher must be maintained. Networks lacking DHCP
  NTP options intentionally provide no external clock synchronization.
- **Risks / neutral:** DHCP and ordinary NTP are unauthenticated; the network
  can supply an untrusted time source. Clearing sources stops future external
  synchronization, not the clock or a previously applied time correction.
- Validation must cover received DHCP data, actual IPv4/IPv6 synchronization,
  source removal, no-source behavior and the absence of network listeners.

## Options considered

| Option                       | Verdict      | Reason                                                |
| ---------------------------- | ------------ | ----------------------------------------------------- |
| timesyncd with DHCP dispatcher | ✅          | Native client with explicit DHCP source lifecycle      |
| timesyncd with public fallback | Rejected    | Violates DHCP-only requirement                        |
| Chrony with DHCP adapter      | Not selected | Also needs custom import; no benefit for this purpose |
| NTP-serving configuration     | Rejected    | Explicitly forbidden                                  |

## References

- [ArchWiki dispatcher example](https://wiki.archlinux.org/title/NetworkManager#Dynamically_set_NTP_servers_received_via_DHCP_with_systemd-timesyncd).
- [Time module](../../modules/time-sync.nix).
- [POSIX sh DHCP dispatcher](../../modules/time-sync/dhcp-sources.sh).
- [Administration](../administration.md#time-synchronization).
- [Validation evidence](../time-synchronization.md).
- Pinned Nixpkgs `nixos/modules/system/boot/timesyncd.nix` and
  `nixos/modules/services/networking/ntp/chrony.nix`.
