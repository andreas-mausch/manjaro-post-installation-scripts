#!/usr/bin/env bash
set -euo pipefail

# Script to decrypt external USB drives using dm-crypt (plain mode)
# Key is derived via Argon2 using the drive's serial number

usage() {
  echo "Usage:"
  echo "  $0 list"
  echo "  $0 <device-path>"
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: Required command '$1' not found"
    exit 1
  }
}

for cmd in lsblk udevadm sed cryptsetup openssl udisksctl pass; do
  require "${cmd}"
done

[[ $# -eq 1 ]] || usage

if [[ "${1}" == "list" ]]; then
  lsblk --fs --paths --output=+SIZE,TRAN | grep usb
  exit 0
fi

DEVICE_PATH="${1}"

if [[ ! -b "${DEVICE_PATH}" ]]; then
  echo "Error: '${DEVICE_PATH}' is not a valid block device"
  exit 1
fi

SERIAL_NUMBER=$(udevadm info "${DEVICE_PATH}" | sed -n 's/^E: ID_SERIAL_SHORT=//p')

if [[ -z "${SERIAL_NUMBER}" ]]; then
  echo "Error: Could not extract serial number"
  exit 1
fi

MAPPING_NAME="disk_${SERIAL_NUMBER}"

if [[ -e "/dev/mapper/${MAPPING_NAME}" ]]; then
  echo "Error: Mapping already exists: ${MAPPING_NAME}"
  exit 1
fi

openssl kdf -binary \
  -keylen 64 \
  -kdfopt pass:$(pass disk-encryption | head -n 1 | tr -d '\n') \
  -kdfopt salt:"HDD|Serial:${SERIAL_NUMBER}" \
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
  "${DEVICE_PATH}" \
  "${MAPPING_NAME}"

udisksctl mount --filesystem-type=ext4 --block-device="/dev/mapper/${MAPPING_NAME}"

echo
echo "✅ Device mounted successfully."
echo "After usage, you still need to unmount and close the cryptsetup device again."
echo
echo "To unmount:"
echo "  udisksctl unmount --block-device=/dev/mapper/${MAPPING_NAME}"
echo "  sudo cryptsetup close ${MAPPING_NAME}"
echo
echo "Optional power off:"
echo "  udisksctl power-off --block-device=${DEVICE_PATH}"
