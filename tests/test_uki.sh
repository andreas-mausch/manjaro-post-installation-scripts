#!/usr/bin/env bash
# Local integration test: requires unprivileged user/mount namespaces and objcopy.
# Usage: bash tests/test_uki.sh /nix/store/.../bin/prepare-system-uki SYSTEM_PATH
set -euo pipefail
builder=$1
system=$2
temporary=$(mktemp -d /tmp/opencode/uki-test-XXXXXX)
trap 'rmdir "$temporary"' EXIT
unshare --user --map-root-user --mount --fork bash -s -- "$builder" "$system" "$temporary" <<'EOF'
set -euo pipefail
builder=$1
system=$2
esp=$3
# Reject an unmounted destination before writing anything.
if "$builder" "$system" "$esp"; then
    echo "Unexpectedly accepted an unmounted EFI destination" >&2
    exit 1
fi
# All writes go to an ephemeral filesystem in this mount namespace.
mount -t tmpfs tmpfs "$esp"
"$builder" "$system" "$esp"
image="$esp/EFI/my-os-setup/$(basename "$system").efi"
test -s "$image"
before=$(sha256sum "$image")
"$builder" "$system" "$esp"
test "$before" = "$(sha256sum "$image")"
objcopy --dump-section .cmdline="$esp/cmdline" "$image"
grep -aF "init=$system/init" "$esp/cmdline"
test -z "$(find "$esp/EFI/my-os-setup" -name '.uki-*' -print)"
echo "UKI: target init embedded, repeat unchanged, mount guard and temporary cleanup OK"
EOF
