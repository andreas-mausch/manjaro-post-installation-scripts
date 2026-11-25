"""Small Calamares job adapter: native UI/storage, pinned M5 flake deployment."""
import json
from pathlib import Path
import re
import subprocess

import libcalamares


def host(*args, input=None, capture=False):
    # Use Calamares' existing Polkit environment; never put secrets in arguments.
    return subprocess.run(
        ["pkexec", *map(str, args)], input=input, text=True, check=True,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
    )


def write_file(path, contents, mode="0644"):
    host("install", "-m", mode, "/dev/null", path)
    host("tee", path, input=contents)


def validate_selection(gs):
    if gs.value("firmwareType") != "efi":
        raise ValueError("Den Stick im UEFI-Modus booten; Secure Boot deaktivieren.")
    choices = gs.value("partitionChoices") or {}
    if choices.get("install") != "erase" or choices.get("swap") != "none":
        raise ValueError("Für dieses Image: gesamte SSD löschen, kein Swap.")
    passphrase = gs.value("luksPassphrase")
    if not passphrase or len(libcalamares.utils.obscure(passphrase)) < 12:
        raise ValueError("Verschlüsselung aktivieren; LUKS-Passphrase mindestens 12 Zeichen.")
    username = gs.value("username") or ""
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,30}", username) or username in {
        "root", "gufo", "nixos", "nobody", "daemon",
    }:
        raise ValueError("Ungültiger oder reservierter Benutzername.")
    password = gs.value("password")
    if not password or len(libcalamares.utils.obscure(password)) < 8:
        raise ValueError("Benutzerpasswort mindestens 8 Zeichen.")
    if gs.value("autoLoginUser"):
        raise ValueError("Automatische Anmeldung ist für dieses Image deaktiviert.")


def validate_mounts(gs):
    partitions = gs.value("partitions") or []
    roots = [p for p in partitions if p.get("mountPoint") == "/"]
    boots = [p for p in partitions if p.get("mountPoint") == "/boot"]
    if len(roots) != 1 or roots[0].get("fsName") != "luks2" or roots[0].get("fs") != "btrfs":
        raise ValueError("Die Root-Partition muss Btrfs innerhalb von LUKS2 sein.")
    if len(boots) != 1 or boots[0].get("fs") != "fat32" or boots[0].get("fsName") in {"luks", "luks2"}:
        raise ValueError("/boot muss eine unverschlüsselte EFI-/FAT32-Partition sein.")
    if any(p.get("fs") == "linuxswap" for p in partitions):
        raise ValueError("Dieses Image unterstützt keinen Swap.")
    root = Path(gs.value("rootMountPoint") or "")
    if not root.is_absolute() or root == Path("/"):
        raise ValueError("Ungültiger Installations-Mountpoint.")
    host("mountpoint", "-q", root)
    host("mountpoint", "-q", root / "boot")
    return root


def identity(gs):
    locale = gs.value("localeConf") or {}
    return {
        "username": gs.value("username"),
        "fullname": gs.value("fullname") or "",
        "hostname": gs.value("hostname") or "bosgame-m5",
        "timezone": "/".join(filter(None, [gs.value("locationRegion"), gs.value("locationZone")])) or "Europe/Berlin",
        "locale": (locale.get("LANG") or "de_DE.UTF-8").split("/")[0],
        "keyboardLayout": gs.value("keyboardLayout") or "de",
        "keyboardVariant": gs.value("keyboardVariant") or "",
        "consoleKeyMap": (gs.value("keyboardVConsoleKeymap") or "de").strip(),
    }


def deploy(gs, config):
    root = validate_mounts(gs)
    source = Path(config["source"])
    models = Path(config["models"])
    if not (source / "flake.lock").is_file() or not (models / "flash-next-q4").is_dir():
        raise ValueError("Gepinnte Konfiguration oder Modelle fehlen im Image.")
    destination = root / "etc/nixos"
    host("mkdir", "-p", destination)
    host("cp", "-r", str(source) + "/.", destination)
    host("chmod", "-R", "u+rwX,go+rX,go-w", destination)
    write_file(destination / "installation.json", json.dumps(identity(gs), indent=2) + "\n")
    hardware = host("nixos-generate-config", "--root", root, "--show-hardware-config", capture=True).stdout
    write_file(destination / "hardware-configuration.nix", hardware)
    secrets = root / "var/lib/nixos-secrets"
    host("install", "-d", "-m", "0700", secrets)
    password = libcalamares.utils.obscure(gs.value("password"))
    hashed = subprocess.run(
        ["mkpasswd", "--method=yescrypt", "--stdin"], input=password + "\n",
        text=True, check=True, stdout=subprocess.PIPE,
    ).stdout
    write_file(secrets / "user-password.hash", hashed, "0600")
    # No passwords/passphrases are copied into the flake or the Nix Store.
    del password, hashed
    libcalamares.job.setprogress(0.1)
    install_command = [
        "nixos-install", "--root", root, "--no-root-passwd",
        "--flake", f"path:{destination}#m5", "--no-write-lock-file",
        "--no-update-lock-file", "--no-channel-copy",
        "--option", "build-dir", "/nix/var/nix/builds",
    ]
    if config.get("offline", False):
        # nixos-install adds the live store as an auto/local substituter.
        # No remote substitutes, builders or registry fetches; the network
        # namespace also blocks accidental fixed-output downloads.
        install_command += [
            "--option", "substituters", "",
            "--option", "builders", "",
            "--option", "flake-registry", "",
        ]
        install_command = ["unshare", "--net", "--", *install_command]
    host(*install_command)
    libcalamares.job.setprogress(0.7)
    target_models = root / "var/lib/gufo/models"
    host("mkdir", "-p", target_models)
    host("cp", "-rL", str(models) + "/.", target_models)
    host("chmod", "-R", "u+rwX,go+rX,go-w", target_models)
    host("nixos-enter", "--root", root, "-c", "chown -R gufo:gufo /var/lib/gufo")
    libcalamares.job.setprogress(1.0)


def pretty_name():
    return "BOSGAME M5: Konfiguration prüfen und NixOS samt Modellen installieren"


def run():
    try:
        gs = libcalamares.globalstorage
        validate_selection(gs)
        if libcalamares.job.configuration["stage"] == "install":
            deploy(gs, libcalamares.job.configuration)
        return None
    except (ValueError, OSError, subprocess.CalledProcessError):
        # Do not stringify subprocess exceptions: stdin/Calamares storage can
        # contain secrets. Command stderr remains available in the installer log.
        return ("M5-Installation fehlgeschlagen",
                "UEFI, gesamte SSD löschen, LUKS2 mit Btrfs und kein Swap sind erforderlich. "
                "Benutzername und Passwörter prüfen; Details im Installer-Log. "
                "Nach einem Fehler nicht ohne erneute Prüfung formatieren.")
