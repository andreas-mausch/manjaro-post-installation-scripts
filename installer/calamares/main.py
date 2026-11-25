"""Small Calamares job adapter: native UI/storage, pinned M5 flake deployment."""
import json
from datetime import datetime
import logging
from pathlib import Path
import re
import subprocess

import libcalamares


logger = logging.getLogger("m5-installer")


def host(*args, input=None, capture=False):
    # Use Calamares' existing Polkit environment; never put secrets in arguments.
    logger.warning("M5 installer: running %s", Path(str(args[0])).name)
    return subprocess.run(
        ["pkexec", *map(str, args)], input=input, text=True, check=True,
        # Preserve original diagnostics in Calamares' inherited log streams.
        stdout=subprocess.PIPE if capture else None,
    )


def write_file(path, contents, mode="0644"):
    host("install", "-m", mode, "/dev/null", path)
    host("tee", path, input=contents)


def validate_selection(gs):
    if gs.value("packagechooser_models") not in {"qwen", "without-models"}:
        raise ValueError("Modellgewichte mit oder ohne Kopieren auswählen.")
    if gs.value("firmwareType") != "efi":
        raise ValueError("Den Stick im UEFI-Modus booten; Secure Boot deaktivieren.")
    choices = gs.value("partitionChoices") or {}
    if choices.get("install") != "erase" or choices.get("swap") != "none":
        raise ValueError("Für dieses Image: gesamte SSD löschen, kein Swap.")
    # Encryption is optional; Calamares validates matching, nonempty passphrases
    # in the partition UI. Do not impose a different policy during installation.
    username = gs.value("username") or ""
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,30}", username) or username in {
        "root", "gufo", "nixos", "nobody", "daemon",
    }:
        raise ValueError("Ungültiger oder reservierter Benutzername.")
    # The native users module enforces the configured password requirements.
    if gs.value("autoLoginUser"):
        raise ValueError("Automatische Anmeldung ist für dieses Image deaktiviert.")


def validate_mounts(gs):
    partitions = gs.value("partitions") or []
    roots = [p for p in partitions if p.get("mountPoint") == "/"]
    boots = [p for p in partitions if p.get("mountPoint") == "/boot"]
    if len(roots) != 1:
        raise ValueError("Genau eine Root-Partition muss vorhanden sein.")
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


def deploy(gs, config, context=None):
    context = context if context is not None else {}
    context["phase"] = "Ziel-Mounts prüfen"
    root = validate_mounts(gs)
    source = Path(config["source"])
    models = Path(config["models"])
    if not (source / "flake.lock").is_file() or not (models / "flash-next-q4").is_dir():
        raise ValueError("Gepinnte Konfiguration oder Modelle fehlen im Image.")
    destination = root / "etc/nixos"
    context["phase"] = "Zielkonfiguration vorbereiten"
    host("mkdir", "-p", destination)
    host("cp", "-r", str(source) + "/.", destination)
    host("chmod", "-R", "u+rwX,go+rX,go-w", destination)
    write_file(destination / "installation.json", json.dumps(identity(gs), indent=2) + "\n")
    context["phase"] = "Hardwarekonfiguration erzeugen"
    hardware = host("nixos-generate-config", "--root", root, "--show-hardware-config", capture=True).stdout
    write_file(destination / "hardware-configuration.nix", hardware)
    context["phase"] = "Benutzerzugang vorbereiten"
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
    context["phase"] = "Offline-Systeminstallation" if config.get("offline", False) else "Systeminstallation"
    host(*install_command)
    libcalamares.job.setprogress(0.7)
    if gs.value("packagechooser_models") == "qwen":
        context["phase"] = "Modellgewichte kopieren"
        target_models = root / "var/lib/gufo/models"
        host("mkdir", "-p", target_models)
        host("cp", "-rL", str(models) + "/.", target_models)
        host("chmod", "-R", "u+rwX,go+rX,go-w", target_models)
        host("nixos-enter", "--root", root, "-c", "chown -R gufo:gufo /var/lib/gufo")
    libcalamares.job.setprogress(1.0)


def pretty_name():
    return "BOSGAME M5: NixOS und optional Modellgewichte installieren"


def run():
    context = {"phase": "Vorprüfung"}
    started = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
    # This stage runs after Calamares' partition and mount jobs, even if the
    # adapter's own validation fails before deployment starts.
    installation_started = libcalamares.job.configuration.get("stage") == "install"
    try:
        gs = libcalamares.globalstorage
        validate_selection(gs)
        if installation_started:
            context["phase"] = "Systeminstallation vorbereiten"
            deploy(gs, libcalamares.job.configuration, context)
        return None
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # Never log exception repr, command arguments, stdin or traceback:
        # subprocess exceptions and paths may contain sensitive information.
        if isinstance(error, ValueError):
            detail = str(error)
        elif isinstance(error, subprocess.CalledProcessError):
            command = error.cmd
            program = Path(str(command[0])).name if isinstance(command, (list, tuple)) and command else "Unterprozess"
            if program == "pkexec" and len(command) > 1:
                program = Path(str(command[1])).name
            # Only expose names of commands used by this adapter.
            if program not in {"mountpoint", "mkdir", "cp", "chmod", "install", "tee",
                               "nixos-generate-config", "mkpasswd", "unshare", "nixos-install", "nixos-enter"}:
                program = "Unterprozess"
            if program in {"unshare", "nixos-install"}:
                # An exit code alone cannot distinguish the wrapper from its
                # child. Report the operation, not an invented root cause.
                detail = f"Systeminstallationsaufruf fehlgeschlagen (Exit-Code {error.returncode})."
            else:
                detail = f"{program} fehlgeschlagen (Exit-Code {error.returncode})."
        else:
            detail = f"Betriebssystemfehler (errno {error.errno})."
        phase = context["phase"]
        logger.error("M5 installer: %s: %s", phase, detail)
        state = (
            "Der Zieldatenträger wurde bereits partitioniert; die Installation ist unvollständig. "
            "Nicht ohne Prüfung erneut installieren oder formatieren."
            if installation_started else
            "Die Vorprüfung wurde vor dem Partitionierungsjob abgebrochen."
        )
        return ("M5-Installation fehlgeschlagen",
                f"Phase: {phase}. {detail}\n\n{state}\n\n"
                "Originaldiagnostik: Calamares-Ausgabe oder im Live-Terminal:\n"
                f"sudo journalctl -b --since '{started}' --no-pager\n\n"
                "Die erste Fehlermeldung vor den Folgefehlern prüfen. "
                "Protokolle vor Weitergabe auf sensible Daten prüfen; kein automatischer Upload.")
