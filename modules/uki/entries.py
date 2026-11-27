"""Keep current, backup and installation UKI entries using virt-firmware."""
from datetime import datetime
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from virt.firmware.bootcfg import linuxcfg
from virt.firmware.efi import bootentry, ucs16


LABELS = {"current": "Aktuell", "backup": "Backup", "installation": "Installation"}


def next_roles(old, target, installation, fallback):
    current = old.get("current", fallback)
    roles = {"current": target}
    backup = current if current != target else old.get("backup")
    if backup and backup != target:
        roles["backup"] = backup
    if installation:
        roles["installation"] = installation
    return roles


def save_state(path, roles):
    # A failed update leaves the old role state available for retry.
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".roles-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            json.dump(roles, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def register_roles(cfg, images):
    keep = set()
    partition = None
    for role, image in images.items():
        efifile = linuxcfg.LinuxEfiFile(str(image))
        devicepath = efifile.dev_path_file()
        partition = bytes(devicepath[0])
        title = "NixOS " + LABELS[role] + " " + datetime.fromtimestamp(image.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
        number = next((nr for nr, entry in cfg.bentr.items()
                       if entry and str(entry.title) == title
                       and bytes(entry.devicepath) == bytes(devicepath)), None)
        if number is None:
            entry = bootentry.BootEntry(title=ucs16.from_string(title),
                                       attr=bootentry.LOAD_OPTION_ACTIVE,
                                       devicepath=devicepath)
            number = cfg.add_entry(entry)
            cfg.linux_write_entry(number)
        keep.add(number)
        cfg.set_boot_order(number, -1)
    # Make new entries selectable before removing superseded ones.
    cfg.linux_update_order()
    return keep, partition


def remove_superseded(cfg, keep, partition):
    for nr, entry in list(cfg.bentr.items()):
        if nr in keep or not entry or len(entry.devicepath) != 2:
            continue
        if bytes(entry.devicepath[0]) != partition:
            continue
        node = entry.devicepath[1]
        if (node.devtype, node.subtype) != (0x04, 0x04):
            continue
        filepath = str(ucs16.from_ucs16(node.data, 0))
        if not filepath.lower().startswith("\\efi\\my-os-setup\\"):
            continue
        cfg.remove_entry(nr)
        cfg.linux_remove_entry(nr)
    cfg.linux_update_order()
    cfg.linux_update_next()


def manage(system, esp, state, installation_root, fallback):
    system, esp, state = Path(system).resolve(strict=True), Path(esp), Path(state)
    state.parent.mkdir(parents=True, exist_ok=True)
    with open(str(state) + ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old = json.loads(state.read_text()) if state.exists() else {}
        installation = str(Path(installation_root).resolve(strict=True)) if Path(installation_root).is_symlink() else None
        fallback = str(Path(fallback).resolve(strict=True)) if not old else str(system)
        roles = next_roles(old, str(system), installation, fallback)
        cfg = linuxcfg.LinuxEfiBootConfig()
        if cfg.secureboot:
            raise ValueError("Unsigned UKI role installation requires Secure Boot to be disabled")
        images = {}
        for role, target in roles.items():
            subprocess.run(["prepare-system-uki", target, str(esp)], check=True)
            images[role] = esp / "EFI/my-os-setup" / (Path(target).name + ".efi")
        keep, partition = register_roles(cfg, images)
        save_state(state, roles)
        remove_superseded(cfg, keep, partition)
        print("UKI roles: " + ", ".join(LABELS[role] for role in roles))


if __name__ == "__main__":
    manage(*sys.argv[1:])
