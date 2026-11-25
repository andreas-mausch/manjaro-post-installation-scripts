#!/usr/bin/env python3
"""Interactive installer. Destructive operations are reachable only via main()."""

import argparse
import getpass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


RESERVED_USERS = {"root", "gufo", "nixos", "nobody", "daemon"}


def valid_username(name):
    return bool(re.fullmatch(r"[a-z][a-z0-9_-]{0,30}", name)) and name not in RESERVED_USERS


def eligible_disk(disk):
    """Allow NVMe, SATA and VirtIO disks; never USB or mounted media."""
    def mounted(node):
        return any(node.get("mountpoints") or []) or any(
            mounted(child) for child in node.get("children", [])
        )

    return (
        disk.get("type") == "disk"
        and (
            disk.get("tran") in {"nvme", "sata", "ata", "virtio"}
            or (disk.get("tran") in {None, ""}
                and re.fullmatch(r"/dev/vd[a-z]+", disk.get("path", "")))
        )
        and not disk.get("rm")
        and not disk.get("ro")
        and int(disk.get("size", 0)) >= 256 * 1024**3
        and not mounted(disk)
    )


def partition(disk, number):
    return f"{disk}p{number}" if disk[-1].isdigit() else f"{disk}{number}"


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def list_disks():
    result = run(
        "lsblk", "--json", "--bytes", "--paths",
        "--output", "PATH,TYPE,SIZE,MODEL,SERIAL,TRAN,RM,RO,MOUNTPOINTS",
        capture_output=True, text=True,
    )
    return json.loads(result.stdout)["blockdevices"]


def ask_secret(prompt, minimum):
    while True:
        value = getpass.getpass(prompt)
        if len(value) < minimum:
            print(f"Mindestens {minimum} Zeichen verwenden.")
        elif value == getpass.getpass("Wiederholen: "):
            return value
        else:
            print("Die Eingaben stimmen nicht überein.")


def copy_configuration(source, destination):
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns(
        ".git", "result", "result-*", "__pycache__", "installation.json",
        "hardware-configuration.nix",
    ))
    # Nix store sources are read-only; the installed working copy must be editable.
    for root, directories, files in os.walk(destination):
        os.chmod(root, 0o755)
        for filename in files:
            os.chmod(Path(root) / filename, 0o644)


def install(disk, username, password_hash, luks_password, source, gufo):
    target = Path("/mnt")
    if os.path.ismount(target) or Path("/dev/mapper/cryptroot").exists():
        raise RuntimeError("/mnt oder cryptroot ist bereits belegt. Erst bereinigen oder neu booten.")
    # Recheck the device immediately before formatting.
    candidates = [d for d in list_disks() if d["path"] == disk and eligible_disk(d)]
    if len(candidates) != 1:
        raise RuntimeError("Die Ziel-SSD ist nicht mehr sicher verfügbar.")

    mounted_root = mounted_boot = opened = False
    try:
        # /run is tmpfs on the live image. Never write a LUKS key to the USB stick.
        with tempfile.TemporaryDirectory(prefix="m5-key-", dir="/run") as temporary:
            key = Path(temporary) / "key"
            key.write_bytes(luks_password.encode("utf-8"))
            os.chmod(key, 0o600)
            run("wipefs", "--all", disk)
            run("parted", "--script", disk, "mklabel", "gpt",
                "mkpart", "ESP", "fat32", "1MiB", "1025MiB",
                "set", "1", "esp", "on",
                "mkpart", "primary", "1025MiB", "100%")
            run("partprobe", disk)
            run("udevadm", "settle")
            efi, root = partition(disk, 1), partition(disk, 2)
            run("cryptsetup", "luksFormat", "--type", "luks2", "--batch-mode",
                "--key-file", str(key), root)
            run("cryptsetup", "open", "--key-file", str(key), root, "cryptroot")
            opened = True
        luks_password = None
        run("mkfs.fat", "-F", "32", "-n", "M5EFI", efi)
        run("mkfs.ext4", "-L", "M5ROOT", "/dev/mapper/cryptroot")
        target.mkdir(exist_ok=True)
        run("mount", "/dev/mapper/cryptroot", str(target))
        mounted_root = True
        (target / "boot").mkdir()
        run("mount", "-o", "umask=0077", efi, str(target / "boot"))
        mounted_boot = True

        configuration = target / "etc/nixos"
        configuration.parent.mkdir(parents=True, exist_ok=True)
        copy_configuration(source, configuration)
        (configuration / "installation.json").write_text(
            json.dumps({"username": username}, indent=2) + "\n"
        )
        with (configuration / "hardware-configuration.nix").open("w") as hardware:
            run("nixos-generate-config", "--root", str(target), "--show-hardware-config",
                stdout=hardware)
        secrets = target / "var/lib/nixos-secrets"
        secrets.mkdir(parents=True, mode=0o700)
        secret_hash = secrets / "user-password.hash"
        secret_hash.write_text(password_hash + "\n")
        os.chmod(secret_hash, 0o600)

        print("Installiere NixOS, KDE, Steam und Gufo …")
        run("nixos-install", "--root", str(target), "--no-root-passwd",
            "--flake", f"path:{configuration}#m5", "--no-write-lock-file",
            "--no-update-lock-file", "--no-channel-copy")

        print("Lade die im Gufo-Release festgelegten Modell-Dateien herunter …")
        download_models(target, gufo)
        print("Installation abgeschlossen. Mit reboot neu starten und den Stick entfernen.")
    finally:
        # Keep a failed installation inspectable without leaving its LUKS mapping open.
        if mounted_boot:
            run("umount", str(target / "boot"))
        if mounted_root:
            run("umount", str(target))
        if opened:
            run("cryptsetup", "close", "cryptroot")


def download_models(target, gufo):
    models = target / "var/lib/gufo/models"
    models.mkdir(parents=True, exist_ok=True)
    environment = os.environ.copy()
    environment["GUFO_MODELS_DIR"] = str(models)
    environment["HOME"] = "/run/m5-gufo-download"
    Path(environment["HOME"]).mkdir(exist_ok=True)
    run(gufo, "model", "install", "flash-next-q4", env=environment)
    # Match the installed system's service UID/GID, not those of the live image.
    run("nixos-enter", "--root", str(target), "-c",
        "chown -R gufo:gufo /var/lib/gufo")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--models-only", action="store_true",
                        help="Retry model download on an already mounted installation at /mnt")
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise RuntimeError("Als root ausführen.")
    source = Path(os.environ["M5_SOURCE"])
    gufo = os.environ["M5_GUFO"]
    if args.models_only:
        if not os.path.ismount("/mnt") or not Path("/mnt/etc/nixos/flake.lock").is_file():
            raise RuntimeError("Zuerst die bestehende Installation nach /mnt mounten.")
        download_models(Path("/mnt"), gufo)
        return
    if not Path("/sys/firmware/efi").is_dir():
        raise RuntimeError("Den USB-Stick im UEFI-Modus booten (kein Legacy/CSM).")
    if not (source / "flake.lock").is_file():
        raise RuntimeError("flake.lock fehlt: Dieses Image ist nicht reproduzierbar vorbereitet.")
    print("BOSGAME M5: NixOS + KDE + Steam + Gufo, gesamte SSD mit LUKS2.")
    print("Vorher im BIOS: Secure Boot aus; UMA-Framebuffer möglichst klein (512 MiB).")
    print("Internet wird benötigt. Ethernet empfohlen; WLAN lässt sich mit nmtui einrichten.")
    if input("Netzwerk jetzt mit nmtui einrichten? [j/N] ").lower() == "j":
        run("nmtui")
    run("nm-online", "--timeout=60")
    disks = [disk for disk in list_disks() if eligible_disk(disk)]
    if not disks:
        raise RuntimeError("Kein geeignetes ungemountetes NVMe-, SATA- oder VirtIO-Laufwerk ab 256 GiB gefunden.")
    for index, disk in enumerate(disks, 1):
        print(f"{index}: {disk['path']} | {disk.get('model')} | "
              f"Seriennummer {disk.get('serial')} | {int(disk['size']) / 1024**3:.1f} GiB")
    while True:
        selection = input("Nummer der vollständig zu löschenden SSD: ")
        if selection.isdigit() and 1 <= int(selection) <= len(disks):
            disk = disks[int(selection) - 1]["path"]
            break
    while True:
        username = input("Benutzername (klein geschrieben): ")
        if valid_username(username):
            break
        print("Ungültig oder reserviert. Buchstaben, Ziffern, _ und -; mit Buchstabe beginnen.")
    password = ask_secret("Benutzerpasswort: ", 8)
    hashed = run("mkpasswd", "--method=yescrypt", "--stdin",
                 input=password + "\n", capture_output=True, text=True).stdout.strip()
    password = None
    luks_password = ask_secret("LUKS-Passphrase (bei jedem Boot erforderlich): ", 12)
    confirmation = f"LOESCHEN {disk}"
    print(f"ACHTUNG: Alle Daten auf {disk}, einschließlich Windows, gehen verloren.")
    if input(f"Zur Bestätigung exakt '{confirmation}' eingeben: ") != confirmation:
        print("Abgebrochen. Keine Änderungen am Datenträger.")
        return
    install(disk, username, hashed, luks_password, source, gufo)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(f"Installation fehlgeschlagen: {error}")
        raise SystemExit(1)
    except (KeyboardInterrupt, EOFError):
        print("\nAbgebrochen.")
        raise SystemExit(130)
