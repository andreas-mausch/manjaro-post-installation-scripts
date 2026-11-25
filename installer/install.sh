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

add_model_files() {
  local -n arguments=$1
  local model
  # cp -a in disko-install must not preserve link-farm symlinks.
  while IFS= read -r -d '' model; do
    arguments+=(--extra-files "$(readlink -f "$model")" "/var/lib/gufo/models/${model#"$M5_MODELS/"}")
  done < <(find -L "$M5_MODELS" -type f -print0)
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

  local staging configuration
  staging=$(mktemp -d /run/m5-install.XXXXXXXX)
  # Disko-install unmounts its target; also clean up partial failures and keys.
  trap 'trap - EXIT; set +e; mountpoint -q /mnt && umount -R /mnt; [[ ! -e /dev/mapper/cryptroot ]] || cryptsetup close cryptroot; rm -rf -- "$staging"' EXIT
  configuration=$staging/configuration
  mkdir "$configuration"
  cp -r -- "$M5_SOURCE/." "$configuration/"
  chmod -R u+rwX,go+rX,go-w "$configuration"
  jq -n --arg username "$username" --arg disk "$disk" \
    '{username: $username, disk: $disk}' > "$configuration/installation.json"
  # Scan the machine before installation; Disko supplies all storage settings.
  nixos-generate-config --no-filesystems --show-hardware-config > "$configuration/hardware-configuration.nix"
  install -d -m 0700 "$staging/secrets"
  (umask 077; printf '%s\n' "$hashed" > "$staging/secrets/user-password.hash")
  unset hashed
  local -a extra_files=(
    --extra-files "$configuration" /etc/nixos
    --extra-files "$staging/secrets" /var/lib/nixos-secrets
  )
  add_model_files extra_files
  echo 'Disko-install baut und installiert das System samt Modellen vom Stick …'
  disko-install --mode format --flake "path:$configuration#m5" \
    --disk main "$disk" --mount-point /mnt --write-efi-boot-entries \
    "${extra_files[@]}"
  cryptsetup close cryptroot
  rm -rf -- "$staging"
  trap - EXIT
  echo 'Installation abgeschlossen. Mit reboot neu starten und Stick entfernen.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
