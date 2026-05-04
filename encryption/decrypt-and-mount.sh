#!/usr/bin/env bash
set -euo pipefail

# dm-crypt (plain) USB helper with Argon2-derived key
# Example call: pass disk-encryption | head -n 1 | tr -d '\n' | decrypt-and-mount open /dev/sdX

usage() {
  cat <<EOF
Usage:
  $0 list
  $0 open <device-path>
  $0 close <device-path|mapping-name>
  $0 status <device-path|mapping-name>
EOF
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: Required command '$1' not found"
    exit 1
  }
}

for cmd in lsblk udevadm sed cryptsetup openssl udisksctl; do
  require "$cmd"
done

[[ $# -ge 1 ]] || usage

COMMAND="$1"
ARG="${2:-}"

get_serial() {
  local dev="$1"
  udevadm info --query=property --name="$dev" \
    | sed -n 's/^ID_SERIAL_SHORT=//p'
}

get_mapping_name() {
  local dev="$1"
  local serial
  serial="$(get_serial "$dev")"
  [[ -n "$serial" ]] || {
    echo "Error: Could not extract serial number"
    exit 1
  }
  echo "disk_${serial}"
}

is_mapped() {
  local name="$1"
  [[ -e "/dev/mapper/$name" ]]
}

get_mapper_path() {
  echo "/dev/mapper/$1"
}

get_mountpoint() {
  lsblk -no MOUNTPOINT "$1" 2>/dev/null || true
}

open_device() {
  local dev="$1"

  [[ -b "$dev" ]] || {
    echo "Error: '$dev' is not a block device"
    exit 1
  }

  local serial mapping
  serial="$(get_serial "$dev")"

  [[ -n "$serial" ]] || {
    echo "Error: Could not extract serial number"
    exit 1
  }

  mapping="disk_${serial}"

  if is_mapped "$mapping"; then
    echo "Already open: $mapping"
    return
  fi

  echo "Opening $dev as $mapping..."

  # argon2 "HDD123456789" -id -t 4 -k 262144 -p 4 -l 64 -v 13 -r | xxd -plain -revert -cols 999999
  # argon2 "HDD123456789" -id -t 4 -k 262144 -p 4 -r -l 64
  # argon2 "HDD123456789" -id -t 4 -m 18 -p 4 -r -l 64
  if [[ -t 0 ]]; then
    # Interactive terminal → prompt safely
    read -rsp "Enter encryption key: " secret
    echo
  else
    # Piped input → read from stdin
    secret="$(cat)"
  fi

  [[ -n "$secret" ]] || {
    echo "Error: empty encryption key"
    exit 1
  }

  openssl kdf -binary \
    -keylen 64 \
    -kdfopt pass:${secret} \
    -kdfopt salt:"HDD|Serial:${serial}" \
    -kdfopt iter:4 \
    -kdfopt memcost:262144 \
    -kdfopt lanes:4 Argon2id \
  | sudo cryptsetup open \
      --type=plain \
      --cipher=aes-xts-plain64 \
      --key-file=- \
      --key-size=512 \
      --keyfile-size=64 \
      --offset=0 \
      --hash=plain \
      "$dev" \
      "$mapping"

  echo "Mounting..."
  udisksctl mount --block-device="$(get_mapper_path "$mapping")"

  echo "✅ Opened and mounted: $mapping"

  echo
  echo "To close later: $0 close $dev"
}

close_device() {
  local input="$1"
  local mapping

  if [[ -b "$input" ]]; then
    mapping="$(get_mapping_name "$input")"
  else
    mapping="$input"
  fi

  if ! is_mapped "$mapping"; then
    echo "Not open: $mapping"
    return
  fi

  local mapper
  mapper="$(get_mapper_path "$mapping")"

  local mountpoint
  mountpoint="$(get_mountpoint "$mapper")"

  if [[ -n "$mountpoint" ]]; then
    echo "Unmounting $mountpoint..."
    udisksctl unmount --block-device="$mapper"
  fi

  echo "Closing $mapping..."
  sudo cryptsetup close "$mapping"

  echo "✅ Closed: $mapping"

  if [[ -b "$input" ]]; then
    echo
    echo "Optional: power off the device:"
    echo "  udisksctl power-off --block-device=${input}"
  fi
}

status_device() {
  local input="$1"
  local mapping dev

  if [[ -b "$input" ]]; then
    dev="$input"
    mapping="$(get_mapping_name "$dev")"
  else
    mapping="$input"
  fi

  echo "Mapping: $mapping"

  if is_mapped "$mapping"; then
    echo "State: OPEN"

    local mapper mountpoint fstype
    mapper="$(get_mapper_path "$mapping")"
    mountpoint="$(get_mountpoint "$mapper")"
    fstype="$(lsblk -no FSTYPE "$mapper" 2>/dev/null || true)"

    echo "Device: $mapper"
    echo "Filesystem: ${fstype:-unknown}"

    if [[ -n "$mountpoint" ]]; then
      echo "Mounted at: $mountpoint"
    else
      echo "Mounted: no"
    fi
  else
    echo "State: CLOSED"
  fi
}

case "$COMMAND" in
  list)
    lsblk --fs --paths --output=NAME,SIZE,FSTYPE,LABEL,TRAN | grep usb || true
    ;;
  open)
    [[ -n "$ARG" ]] || usage
    open_device "$ARG"
    ;;
  close)
    [[ -n "$ARG" ]] || usage
    close_device "$ARG"
    ;;
  status)
    [[ -n "$ARG" ]] || usage
    status_device "$ARG"
    ;;
  *)
    usage
    ;;
esac
