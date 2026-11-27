# Time synchronization validation

2026-11-27: DHCP-only timesyncd with NetworkManager, as specified in
[ADR-0013](decisions/0013-time-synchronization.md).

## Configuration and scope

Shared live and installed profiles enable timesyncd, disable Chrony and have
empty `NTP`, `FallbackNTP` and `networking.timeServers` lists. Only received
DHCP options populate runtime drop-ins. The dispatcher uses NetworkManager's
event environment; an activation refresh reads current options via nmcli.

The shell tests cover IPv4/IPv6 DHCP lists, unchanged updates, source withdrawal,
disconnect and independent interface files. Sources are passed to timesyncd's
native parser; no custom IP parser is maintained. Profile checks cover live configuration;
the live ISO was not separately rebuilt or booted for this change.

## Router and libvirt

Host NetworkManager reported actual received options:

- DHCPv4: `ntp_servers = 10.0.0.1`.
- DHCPv6: `dhcp6_ntp_servers = fd69::1`.

The local libvirt `default` network now advertises these through dnsmasq
`option:ntp-server` and `option6:ntp-server`. DHCPv6 uses `fd42:122::/64`
with IPv6 NAT. No NTP server was started on the host or guest.
The previous network XML is backed up at
`/tmp/opencode/libvirt-default-before-timesync.xml`; the new XML is at
`/tmp/opencode/libvirt-default-dhcp-ntp.xml`. The definition is persistent.

## Installed VM runtime

- The VM received both advertised addresses through DHCPv4 and DHCPv6.
- IPv4 synchronization with `10.0.0.1`: successful NTP response, stratum 2.
- IPv6-only source isolation: temporarily removed the IPv4 address from the
  runtime drop-in, retaining only the received DHCPv6 source. timesyncd
  contacted `[fd69::1]:123` and logged successful initial synchronization;
  `timesync-status` reported stratum 2 and a received packet.
- Simulated DHCP source withdrawal by invoking the installed dispatcher with
  both DHCP NTP environment variables absent. It removed the drop-in and
  restarted timesyncd; status reported `Server: n/a`, poll interval 0 and
  packet count 0. No static or fallback source appeared. This was a dispatcher
  simulation, not a separate DHCP-server lease-withdrawal test.
- Reattached the VM network interface to exercise actual reconnect events.
  Both sources reappeared automatically; IPv4 synchronization succeeded again.
- Privileged `ss -lntup` showed no timesyncd network listener for either address
  family. Unrelated SSH, printing and DHCP-client sockets remained unchanged.

The final VM configuration retains the shared time module as a local import
under `/etc/nixos` and has both DHCP sources restored. A previous successful
clock correction is not undone when sources disappear; no-source policy means
no further external time synchronization, not deliberately making the clock
incorrect.
