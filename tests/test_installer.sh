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
temporary=$(mktemp -d)
trap 'rm -rf -- "$temporary"' EXIT
M5_MODELS=$temporary/models
mkdir -p "$M5_MODELS/flash-next-q4/UD-Q4_K_XL"
printf 'test model' > "$temporary/store-blob"
ln -s "$temporary/store-blob" "$M5_MODELS/flash-next-q4/UD-Q4_K_XL/shard.gguf"
extra_files=()
add_model_files extra_files
[[ ${#extra_files[@]} == 3 ]]
[[ ${extra_files[0]} == --extra-files ]]
[[ ${extra_files[1]} == "$temporary/store-blob" ]]
[[ ${extra_files[2]} == /var/lib/gufo/models/flash-next-q4/UD-Q4_K_XL/shard.gguf ]]
cp -a -- "${extra_files[1]}" "$temporary/installed.gguf"
[[ ! -L $temporary/installed.gguf ]]
cmp "$temporary/store-blob" "$temporary/installed.gguf"
echo 'Installer validation tests passed.'
