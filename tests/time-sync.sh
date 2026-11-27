#!/bin/sh
set -eu
mkdir -p "$TMPDIR/bin" "$TMPDIR/run"
sed "s|/run/|$TMPDIR/run/|g" "$1" > "$TMPDIR/dispatcher.sh"
printf '#!/bin/sh\necho restart >> "$TMPDIR/restarts"\n' > "$TMPDIR/bin/systemctl"
chmod +x "$TMPDIR/bin/systemctl"
export PATH="$TMPDIR/bin:$PATH"
script=$TMPDIR/dispatcher.sh
file=$TMPDIR/run/systemd/timesyncd.conf.d/50-dhcp-eth0.conf

# Documentation-only addresses, never personal network addresses.
export DHCP4_NTP_SERVERS=192.0.2.1 DHCP6_DHCP6_NTP_SERVERS=2001:db8::1
sh "$script" eth0 up
grep -Fx 'NTP=2001:db8::1 192.0.2.1' "$file"
sh "$script" eth0 dhcp6-change
test "$(wc -l < "$TMPDIR/restarts")" -eq 1
sh "$script" wlan0 up
sh "$script" eth0 down
test ! -e "$file"
test -e "$TMPDIR/run/systemd/timesyncd.conf.d/50-dhcp-wlan0.conf"
unset DHCP4_NTP_SERVERS DHCP6_DHCP6_NTP_SERVERS
sh "$script" wlan0 dhcp4-change
test ! -e "$TMPDIR/run/systemd/timesyncd.conf.d/50-dhcp-wlan0.conf"
sh "$script" eth0 up
test ! -e "$file"
