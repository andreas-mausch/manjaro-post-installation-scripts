"""Small Calamares job adapter: native UI/storage, pinned M5 flake deployment."""
import json
import gettext
from datetime import datetime
import logging
from pathlib import Path
import re
import subprocess

import libcalamares


logger = logging.getLogger("m5-installer")


def _(message):
    # Resolve the current UI language on each call, including after switching it.
    return gettext.translation(
        "m5-installer", localedir=Path(__file__).parent / "locale",
        languages=libcalamares.utils.gettext_languages(), fallback=True,
    ).gettext(message)


def host(*args, input=None, capture=False, stream=False):
    # Use Calamares' existing Polkit environment; never put secrets in arguments.
    logger.warning("M5 installer: running %s", Path(str(args[0])).name)
    if stream:
        if input is not None or capture:
            raise ValueError("Streaming commands must not receive input or capture output")
        # Calamares forwards process output live to its logger (including the UI).
        # Only opt in for commands without secret input or echoed configuration.
        return libcalamares.utils.host_env_process_output(
            ["pkexec", *map(str, args)], None, "", 0,
        )
    return subprocess.run(
        ["pkexec", *map(str, args)], input=input, text=True, check=True,
        # Inherited streams retain diagnostics, but do not feed the UI log.
        stdout=subprocess.PIPE if capture else None,
    )


def write_file(path, contents, mode="0644"):
    host("install", "-m", mode, "/dev/null", path)
    host("tee", path, input=contents)


def validate_selection(gs):
    if gs.value("packagechooser_models") not in {"qwen", "without-models"}:
        raise ValueError(_("Choose whether to copy model weights."))
    if gs.value("firmwareType") != "efi":
        raise ValueError(_("Boot the USB drive in UEFI mode; disable Secure Boot."))
    choices = gs.value("partitionChoices") or {}
    if choices.get("install") != "erase" or choices.get("swap") != "none":
        raise ValueError(_("For this image: erase the entire SSD and select no swap."))
    # Encryption is optional; Calamares validates matching, nonempty passphrases
    # in the partition UI. Do not impose a different policy during installation.
    username = gs.value("username") or ""
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,30}", username) or username in {
        "root", "gufo", "nixos", "nobody", "daemon",
    }:
        raise ValueError(_("Invalid or reserved username."))
    # The native users module enforces the configured password requirements.
    if gs.value("autoLoginUser"):
        raise ValueError(_("Automatic login is disabled for this image."))


def validate_mounts(gs):
    partitions = gs.value("partitions") or []
    roots = [p for p in partitions if p.get("mountPoint") == "/"]
    boots = [p for p in partitions if p.get("mountPoint") == "/boot"]
    if len(roots) != 1:
        raise ValueError(_("Exactly one root partition is required."))
    if len(boots) != 1 or boots[0].get("fs") != "fat32" or boots[0].get("fsName") in {"luks", "luks2"}:
        raise ValueError(_("/boot must be an unencrypted EFI/FAT32 partition."))
    if any(p.get("fs") == "linuxswap" for p in partitions):
        raise ValueError(_("This image does not support swap."))
    root = Path(gs.value("rootMountPoint") or "")
    if not root.is_absolute() or root == Path("/"):
        raise ValueError(_("Invalid installation mount point."))
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
    context["phase"] = _("Checking target mounts")
    root = validate_mounts(gs)
    source = Path(config["source"])
    models = Path(config["models"])
    if not (source / "flake.lock").is_file() or not (models / "flash-next-q4").is_dir():
        raise ValueError(_("Pinned configuration or models are missing from the image."))
    destination = root / "etc/nixos"
    context["phase"] = _("Preparing target configuration")
    host("mkdir", "-p", destination)
    host("cp", "-r", str(source) + "/.", destination)
    host("chmod", "-R", "u+rwX,go+rX,go-w", destination)
    write_file(destination / "installation.json", json.dumps(identity(gs), indent=2) + "\n")
    context["phase"] = _("Generating hardware configuration")
    hardware = host("nixos-generate-config", "--root", root, "--show-hardware-config", capture=True).stdout
    write_file(destination / "hardware-configuration.nix", hardware)
    context["phase"] = _("Preparing user access")
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
        # Nixpkgs' perl-5.42.3-env for activation sets allowSubstitutes = false.
        # Override that only for installation, never in the target's nix.settings.
        "--option", "substitute", "true",
        "--option", "always-allow-substitutes", "true",
    ]
    # Keep nixos-install's live-store substituter and configured online caches.
    # Offline completeness is verified by network-isolated tests, not by
    # disabling package sources during ordinary installation.
    context["phase"] = _("System installation")
    host(*install_command, stream=True)
    libcalamares.job.setprogress(0.7)
    if gs.value("packagechooser_models") == "qwen":
        context["phase"] = _("Copying model weights")
        target_models = root / "var/lib/gufo/models"
        host("mkdir", "-p", target_models)
        host("cp", "-rL", str(models) + "/.", target_models)
        host("chmod", "-R", "u+rwX,go+rX,go-w", target_models)
        host("nixos-enter", "--root", root, "-c", "chown -R gufo:gufo /var/lib/gufo")
    libcalamares.job.setprogress(1.0)


def pretty_name():
    return _("BOSGAME M5: install NixOS and optional model weights")


def run():
    context = {"phase": _("Preflight checks")}
    started = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
    # This stage runs after Calamares' partition and mount jobs, even if the
    # adapter's own validation fails before deployment starts.
    installation_started = libcalamares.job.configuration.get("stage") == "install"
    try:
        gs = libcalamares.globalstorage
        validate_selection(gs)
        if installation_started:
            context["phase"] = _("Preparing system installation")
            deploy(gs, libcalamares.job.configuration, context)
        return None
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        # Never log exception repr, command arguments, stdin or traceback:
        # subprocess exceptions and paths may contain sensitive information.
        if isinstance(error, ValueError):
            detail = str(error)
        elif isinstance(error, subprocess.CalledProcessError):
            command = error.cmd
            program = Path(str(command[0])).name if isinstance(command, (list, tuple)) and command else _("Subprocess")
            if program == "pkexec" and len(command) > 1:
                program = Path(str(command[1])).name
            # Only expose names of commands used by this adapter.
            if program not in {"mountpoint", "mkdir", "cp", "chmod", "install", "tee",
                               "nixos-generate-config", "mkpasswd", "unshare", "nixos-install", "nixos-enter"}:
                program = _("Subprocess")
            if program in {"unshare", "nixos-install"}:
                # An exit code alone cannot distinguish the wrapper from its
                # child. Report the operation, not an invented root cause.
                detail = _("System installation command failed (exit code {code}).").format(code=error.returncode)
            else:
                detail = _("{program} failed (exit code {code}).").format(program=program, code=error.returncode)
        else:
            detail = _("Operating system error (errno {errno}).").format(errno=error.errno)
        phase = context["phase"]
        logger.error("M5 installer: %s: %s", phase, detail)
        state = (
            _("The target disk has already been partitioned; installation is incomplete. Do not reinstall or format again without checking the disk first.")
            if installation_started else
            _("Preflight checks failed before partitioning.")
        )
        return (_("M5 installation failed"),
                _("Phase: {phase}. {detail}").format(phase=phase, detail=detail) + f"\n\n{state}\n\n" +
                _("Original diagnostics: Calamares output or in the live terminal:") + "\n" +
                f"sudo journalctl -b --since '{started}' --no-pager\n\n" +
                _("Check the first error before subsequent errors. Review logs for sensitive data before sharing; no automatic upload."))
