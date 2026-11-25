#!/usr/bin/env bash
set -euo pipefail
source "$1"
for name in neonew a user_1 user-name; do valid_username "$name"; done
for name in root gufo nobody '' A a/b 1user; do
  if valid_username "$name"; then die "Accepted invalid username: $name"; fi
done
lsblk() {
  cat <<'JSON'
{"blockdevices":[
{"path":"/dev/nvme0n1","type":"disk","tran":"nvme","rm":false,"ro":false,"size":300000000000,"mountpoints":[null]},
{"path":"/dev/sda","type":"disk","tran":"usb","rm":false,"ro":false,"size":300000000000,"mountpoints":[null]},
{"path":"/dev/vda","type":"disk","tran":null,"rm":false,"ro":false,"size":300000000000,"mountpoints":[null]},
{"path":"/dev/nvme1n1","type":"disk","tran":"nvme","rm":false,"ro":false,"size":300000000000,"children":[{"mountpoints":["/mnt"]}]},
{"path":"/dev/sdb","type":"disk","tran":"sata","rm":false,"ro":true,"size":300000000000},
{"path":"/dev/sdc","type":"disk","tran":"sata","rm":true,"ro":false,"size":300000000000},
{"path":"/dev/sdd","type":"disk","tran":"sata","rm":false,"ro":false,"size":100}
]}
JSON
}
[[ $(eligible_disks | jq -sr 'map(.path) | join(",")') == /dev/nvme0n1,/dev/vda ]]
echo 'Installer validation tests passed.'
