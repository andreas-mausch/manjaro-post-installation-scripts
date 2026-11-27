#!/bin/sh
set -efu

dir=/run/systemd/timesyncd.conf.d
mkdir -p "$dir"
exec 9>/run/timesyncd-dhcp.lock
flock 9
changed=false

update() {
    interface=$1
    shift
    case "$interface" in ''|*[!a-zA-Z0-9_.:-]*) return 1 ;; esac
    file=$dir/50-dhcp-$interface.conf
    if [ "$#" -eq 0 ]; then
        if [ -e "$file" ]; then rm -f "$file"; changed=true; fi
    else
        printf '[Time]\nNTP=%s\n' "$*" > "$file.tmp"
        if ! cmp -s "$file.tmp" "$file"; then
            chmod 644 "$file.tmp"
            mv "$file.tmp" "$file"
            changed=true
        else
            rm -f "$file.tmp"
        fi
    fi
}

if [ "${1-}" = --refresh ]; then
    for interface in $(nmcli -g DEVICE device status); do
        servers=$(LC_ALL=C nmcli --escape no -g DHCP4.OPTION,DHCP6.OPTION device show "$interface" |
            sed 's/ | /\n/g' | sed -n -E 's/^(ntp_servers|dhcp6_ntp_servers) = //p')
        # DHCP lists are deliberately split into individual server arguments.
        # shellcheck disable=SC2086
        update "$interface" $servers
    done
else
    case "${2-}" in
        up|dhcp4-change|dhcp6-change)
            # shellcheck disable=SC2086
            update "$1" ${DHCP6_DHCP6_NTP_SERVERS-} ${DHCP4_NTP_SERVERS-}
            ;;
        down) update "$1" ;;
        *) exit 0 ;;
    esac
fi

if "$changed"; then systemctl try-restart systemd-timesyncd.service; fi
