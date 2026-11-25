#!/usr/bin/env bash
# Loaded by writeShellApplication (strict mode and ShellCheck enabled).
# shellcheck disable=SC2154

die() { echo "$*" >&2; exit 1; }

valid_username() {
  [[ $1 =~ ^[a-z][a-z0-9_-]{0,30}$ ]] &&
    [[ ! $1 =~ ^(root|gufo|nixos|nobody|daemon)$ ]]
}

eligible_disks() {
  lsblk --json --bytes --paths \
    --output PATH,TYPE,SIZE,MODEL,SERIAL,TRAN,RM,RO,MOUNTPOINTS |
    jq -c '.blockdevices[] | select(
      .type == "disk" and (.rm | not) and (.ro | not) and
      .size >= 274877906944 and
      ((.tran == "nvme" or .tran == "sata" or .tran == "ata" or .tran == "virtio") or
       ((.tran == null or .tran == "") and (.path | test("^/dev/vd[a-z]+$")))) and
      ([.. | objects | .mountpoints? // [] | .[] | select(. != null and . != "")] | length == 0)
    )'
}

copy_models() {
  mkdir -p /mnt/var/lib/gufo/models
  cp -rL -- "$M5_MODELS/." /mnt/var/lib/gufo/models/
  chmod -R u+rwX,go+rX,go-w /mnt/var/lib/gufo/models
  nixos-enter --root /mnt -c 'chown -R gufo:gufo /var/lib/gufo'
}

main() {
  [[ $EUID == 0 ]] || die 'Als root ausführen.'
  if [[ ${1:-} == --models-only && $# == 1 ]]; then
    mountpoint -q /mnt && [[ -f /mnt/etc/nixos/flake.lock ]] ||
      die 'Zuerst die bestehende Installation nach /mnt mounten.'
    copy_models
    return
  fi
  [[ $# == 0 ]] || die 'Verwendung: install-m5 [--models-only]'
  [[ -d /sys/firmware/efi ]] || die 'Den USB-Stick im UEFI-Modus booten.'
  [[ -f $M5_SOURCE/flake.lock ]] || die 'flake.lock fehlt.'
  [[ -d $M5_MODELS/flash-next-q4 ]] || die 'Modelle fehlen auf dem Installationsmedium.'
  echo 'BOSGAME M5: NixOS + KDE + Steam + Gufo, gesamte SSD mit LUKS2.'
  echo 'Vorher im BIOS: Secure Boot aus; UMA-Framebuffer möglichst klein (512 MiB).'
  echo 'Internet für die Systeminstallation erforderlich; Modelle liegen auf dem Stick.'
  local answer disk username password repeat hashed confirmation selection
  read -r -p 'Netzwerk jetzt mit nmtui einrichten? [j/N] ' answer
  [[ ${answer,,} != j ]] || nmtui
  nm-online --timeout=60
  local -a disks
  mapfile -t disks < <(eligible_disks)
  [[ ${#disks[@]} -gt 0 ]] || die 'Keine geeignete ungemountete SSD ab 256 GiB gefunden.'
  local i
  for i in "${!disks[@]}"; do
    printf '%s: %s\n' "$((i + 1))" "$(jq -r '"\(.path) | \(.model) | Seriennummer \(.serial) | \(.size / 1073741824) GiB"' <<< "${disks[i]}")"
  done
  while true; do
    read -r -p 'Nummer der vollständig zu löschenden SSD: ' selection
    if [[ $selection =~ ^[1-9][0-9]{0,3}$ ]] && ((10#$selection <= ${#disks[@]})); then
      disk=$(jq -r .path <<< "${disks[10#$selection - 1]}")
      break
    fi
  done
  while true; do
    read -r -p 'Benutzername (klein geschrieben): ' username
    if valid_username "$username"; then break; fi
    echo 'Ungültiger oder reservierter Benutzername.'
  done
  while true; do
    read -r -s -p 'Benutzerpasswort (mindestens 8 Zeichen): ' password; echo
    read -r -s -p 'Wiederholen: ' repeat; echo
    if [[ ${#password} -ge 8 && $password == "$repeat" ]]; then break; fi
    echo 'Zu kurz oder Eingaben unterschiedlich.'
  done
  hashed=$(printf '%s\n' "$password" | mkpasswd --method=yescrypt --stdin)
  unset password repeat
  echo "ACHTUNG: Alle Daten auf $disk, einschließlich Windows, gehen verloren."
  read -r -p "Zur Bestätigung exakt 'LOESCHEN $disk' eingeben: " confirmation
  [[ $confirmation == "LOESCHEN $disk" ]] || { echo 'Abgebrochen. Keine Änderungen.'; return; }
  ! mountpoint -q /mnt && [[ ! -e /dev/mapper/cryptroot ]] || die '/mnt oder cryptroot ist belegt.'
  eligible_disks | jq -e --arg disk "$disk" 'select(.path == $disk)' >/dev/null ||
    die 'Die Ziel-SSD ist nicht mehr sicher verfügbar.'

  # Also handles partially completed Disko operations. Never formats on cleanup.
  trap 'trap - EXIT; set +e; mountpoint -q /mnt/boot && umount /mnt/boot; mountpoint -q /mnt && umount /mnt; [[ ! -e /dev/mapper/cryptroot ]] || cryptsetup close cryptroot' EXIT
  echo 'Disko richtet die SSD ein und fragt die LUKS-Passphrase ab …'
  disko --mode destroy,format,mount --yes-wipe-all-disks \
    --argstr device "$disk" --arg pkgs "import $M5_NIXPKGS {}" \
    "$M5_SOURCE/modules/disk-layout.nix"
  mkdir -p /mnt/etc/nixos
  cp -r -- "$M5_SOURCE/." /mnt/etc/nixos/
  chmod -R u+rwX,go+rX,go-w /mnt/etc/nixos
  jq -n --arg username "$username" --arg disk "$disk" \
    '{username: $username, disk: $disk}' > /mnt/etc/nixos/installation.json
  nixos-generate-config --root /mnt --no-filesystems --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix
  install -d -m 0700 /mnt/var/lib/nixos-secrets
  (umask 077; printf '%s\n' "$hashed" > /mnt/var/lib/nixos-secrets/user-password.hash)
  unset hashed
  nixos-install --root /mnt --no-root-passwd --flake path:/mnt/etc/nixos#m5 \
    --no-write-lock-file --no-update-lock-file --no-channel-copy
  echo 'Kopiere Modell-Dateien vom Installationsmedium …'
  copy_models
  umount /mnt/boot
  umount /mnt
  cryptsetup close cryptroot
  trap - EXIT
  echo 'Installation abgeschlossen. Mit reboot neu starten und Stick entfernen.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
