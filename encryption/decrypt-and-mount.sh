#!/usr/bin/env -S bash -e

# Script to decrypt external USB drives
# using dm-crypt in plain mode
# with a key derived via Argon2 using the drive's serial number

# Usage:    decrypt-and-mount list
# and then: decrypt-and-mount /dev/sdX

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <device-path>"
  exit 1
fi

if [[ "${1}" == "list" ]]; then
  lsblk --fs --paths --output=+SIZE,TRAN | grep usb
  exit 0
fi

DEVICE_PATH="${1}"
SERIAL_NUMBER=$(udevadm info "${DEVICE_PATH}" | sed -n 's/^E: ID_SERIAL_SHORT=//p')

if [[ -z "$SERIAL_NUMBER" ]]; then
  echo "Error: Could not extract serial number"
  exit 1
fi

MAPPING_NAME="disk_${SERIAL_NUMBER}"

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
echo After usage, you still need to unmount and close the cryptsetup device again.
echo
echo "udisksctl unmount --block-device=/dev/mapper/${MAPPING_NAME}"
echo "sudo cryptsetup close ${MAPPING_NAME}"
echo
echo "And optionally, turn off the disk:"
echo "udisksctl power-off --block-device=${DEVICE_PATH}"
