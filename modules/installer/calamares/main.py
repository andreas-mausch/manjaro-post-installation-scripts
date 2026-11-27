"""Small Calamares job adapter: native UI/storage, pinned desktop deployment."""
import json
import gettext
from datetime import datetime
import logging
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import time

import libcalamares


logger = logging.getLogger("desktop-installer")


def _(message):
    # Resolve the current UI language on each call, including after switching it.
    return gettext.translation(
        "desktop-installer", localedir=Path(__file__).parent / "locale",
        languages=libcalamares.utils.gettext_languages(), fallback=True,
    ).gettext(message)


def host(*args, input=None, capture=False, stream=False):
    # Use Calamares' existing Polkit environment; never put secrets in arguments.
    logger.warning("Desktop installer: running %s", Path(str(args[0])).name)
    if stream:
        if input is not None or capture:
            raise ValueError("Streaming commands must not receive input or capture output")
        # A callback is required to enable Calamares' live output processing.
        # Only opt in for commands without secret input or echoed configuration.
        command = ["pkexec", *map(str, args)]
        # Retain complete output independently of Calamares/journal verbosity
        # and rate limiting. mkstemp creates a private (0600) log file.
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                         prefix="desktop-install-", suffix=".log",
                                         delete=False) as log:
            logger.warning("Desktop installer: diagnostics saved to %s", log.name)

            def report_output(line):
                log.write(str(line) + "\n")
                log.flush()
                libcalamares.utils.debug(line)

            try:
                return libcalamares.utils.host_env_process_output(
                    command, report_output, "", 0,
                )
            except subprocess.CalledProcessError as error:
                # Calamares may omit the command in its exception.
                error.cmd = command
                error.diagnostics_path = log.name
                raise
    return subprocess.run(
        ["pkexec", *map(str, args)], input=input, text=True, check=True,
        # Inherited streams retain diagnostics, but do not feed the UI log.
        stdout=subprocess.PIPE if capture else None,
    )


def write_file(path, contents, mode="0644"):
    host("install", "-m", mode, "/dev/null", path)
    # tee echoes its input; never expose configuration or password hashes.
    host("tee", path, input=contents, capture=True)


def validate_selection(gs, with_models=True):
    if with_models and gs.value("packagechooser_models") not in {"qwen", "without-models"}:
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
        "root", "gufo", "nixos", "nobody", "daemon", "sshd",
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
    hostname = gs.value("hostname")
    if not isinstance(hostname, str) or not hostname.strip():
        raise ValueError(_("Calamares did not provide a hostname."))
    locale = gs.value("localeConf") or {}
    return {
        "username": gs.value("username"),
        "fullname": gs.value("fullname") or "",
        "hostname": hostname,
        "timezone": "/".join(filter(None, [gs.value("locationRegion"), gs.value("locationZone")])) or "Europe/Berlin",
        "locale": (locale.get("LANG") or "de_DE.UTF-8").split("/")[0],
        "keyboardLayout": gs.value("keyboardLayout") or "de",
        "keyboardVariant": gs.value("keyboardVariant") or "",
        "consoleKeyMap": (gs.value("keyboardVConsoleKeymap") or "de").strip(),
    }


def nix_string(value):
    # JSON string escapes are valid here; additionally prevent Nix interpolation.
    return json.dumps(value, ensure_ascii=False).replace("${", "\\${")


def local_configuration(installation, spice=False, ssh=False):
    quoted = {key: nix_string(value) for key, value in installation.items()}
    guest_integration = "  services.spice-vdagentd.enable = true;\n\n" if spice else ""
    ssh_access = (
        "  services.openssh.enable = true;\n"
        f'  users.users.{quoted["username"]}.openssh.authorizedKeys.keyFiles = [ ./ssh-authorized-keys ];\n\n'
        if ssh else ""
    )
    return f'''# Local settings for this PC. Rebuild with: sudo nixos-rebuild switch
{{ ... }}:
{{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = {quoted["hostname"]};
  time.timeZone = {quoted["timezone"]};
  i18n.defaultLocale = {quoted["locale"]};
  console.keyMap = {quoted["consoleKeyMap"]};
  services.xserver.xkb = {{
    layout = {quoted["keyboardLayout"]};
    variant = {quoted["keyboardVariant"]};
  }};

  users.users.{quoted["username"]} = {{
    isNormalUser = true;
    description = {quoted["fullname"]};
    extraGroups = [ "wheel" "networkmanager" "video" "render" ];
    hashedPasswordFile = "/var/lib/nixos-secrets/user-password.hash";
  }};

{guest_integration}{ssh_access}  # Compatibility baseline, not the current release version.
  system.stateVersion = "26.05";
}}
'''


def deploy(gs, config, context=None):
    context = context if context is not None else {}
    context["phase"] = _("Checking target mounts")
    root = validate_mounts(gs)
    source = Path(config["source"])
    if not (source / "flake.lock").is_file():
        raise ValueError(_("Pinned configuration is missing from the image."))
    destination = root / "etc/nixos"
    context["phase"] = _("Preparing target configuration")
    host("mkdir", "-p", destination)
    host("cp", "-r", str(source) + "/.", destination)
    host("chmod", "-R", "u+rwX,go+rX,go-w", destination)
    provision_repository(source, destination, config["repositoryRemote"])
    installation = identity(gs) | {"variant": config.get("target", "desktop")}
    write_file(destination / "installation.json", json.dumps(installation, indent=2) + "\n")
    context["phase"] = _("Generating hardware configuration")
    hardware = host("nixos-generate-config", "--root", root, "--show-hardware-config", capture=True).stdout
    write_file(destination / "hardware-configuration.nix", hardware)
    spice = gs.value("packagechooser_spice") == "spice"
    if spice and not Path("/dev/virtio-ports/com.redhat.spice.0").exists():
        raise ValueError(_("The SPICE guest channel is missing."))
    write_file(destination / "configuration.nix", local_configuration(
        installation, spice=spice, ssh=gs.value("packagechooser_ssh") == "ssh"))
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
        "--flake", f"path:{destination}#{installation['hostname']}", "--no-write-lock-file",
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
    libcalamares.job.setprogress(1.0)


def provision_repository(source, destination, remote):
    """Clone the ISO's Git folder locally; never fetch from the network."""
    repository = source / "repository"
    if not (repository / ".git/HEAD").is_file():
        raise ValueError(_("Git repository is missing from the image."))
    git = ["git", "-c", f"safe.directory={repository}"]
    branch = host(*git, "-C", repository, "symbolic-ref", "--short", "HEAD", capture=True).stdout.strip()
    revision = host(*git, "-C", repository, "rev-parse", "HEAD", capture=True).stdout.strip()
    checkout = destination / "my-os-setup"
    host(*git, "clone", "--no-local", "--branch", branch, repository, checkout)
    if host("git", "-C", checkout, "rev-parse", "HEAD", capture=True).stdout.strip() != revision:
        raise ValueError(_("Git repository revision does not match the image."))
    host("git", "-C", checkout, "remote", "set-url", "origin", remote)
    host("git", "-C", checkout, "branch", "--set-upstream-to",
         f"origin/{branch}", branch)
    # The source link is only installation transport, not host configuration.
    host("rm", destination / "repository")


def copy_model_file(source, target, completed, total, report=None):
    # Reset an existing file so its old size cannot inflate retry progress.
    host("install", "-m", "0644", "/dev/null", target)
    command = ["pkexec", "cp", "--reflink=never", "-L", str(source), str(target)]
    with subprocess.Popen(command) as process:
        while True:
            try:
                code = process.wait(timeout=0.25)
            except subprocess.TimeoutExpired:
                copied = min(target.stat().st_size, source.stat().st_size)
                libcalamares.job.setprogress(min(0.99, (completed + copied) / total))
                if report is not None:
                    report(completed + copied)
                continue
            if code:
                raise subprocess.CalledProcessError(code, command)
            break
    if report is not None:
        report(completed + source.stat().st_size)


def model_copy_reporter(total):
    last_time = time.monotonic()
    last_bytes = 0

    def report(copied):
        nonlocal last_time, last_bytes
        now = time.monotonic()
        elapsed = now - last_time
        if elapsed < 3:
            return
        rate = max(0, copied - last_bytes) / elapsed / 1024**2
        libcalamares.utils.debug(_("Model copy: {copied:.2f} / {total:.2f} GiB ({rate:.1f} MiB/s)").format(
            rate=rate, copied=copied / 1024**3, total=total / 1024**3))
        last_time, last_bytes = now, copied

    return report


def copy_models(gs, config, context):
    if gs.value("packagechooser_models") == "without-models":
        libcalamares.job.setprogress(1.0)
        return
    context["phase"] = _("Checking target mounts")
    root = validate_mounts(gs)
    models = Path(config["models"])
    if not models.is_dir():
        raise ValueError(_("Model weights are missing from the image."))
    context["phase"] = _("Copying model weights")
    models_directory = Path(config["modelsDirectory"])
    if not models_directory.is_absolute() or ".." in models_directory.parts or models_directory == Path("/"):
        raise ValueError(_("Invalid model directory."))
    target_models = root / models_directory.relative_to("/")
    # The image uses symlinked Store files/directories; enumerate their contents.
    files = sorted(Path(folder) / name for folder, dirs, names in os.walk(models, followlinks=True)
                   for name in names)
    total = sum(path.stat().st_size for path in files)
    if not files or total == 0:
        raise ValueError(_("Model weights are missing from the image."))
    libcalamares.utils.debug(_("Copying {count} model files: {bytes} bytes ({gib:.2f} GiB) to {target}").format(
        count=len(files), bytes=total, gib=total / 1024**3, target=str(models_directory)))
    libcalamares.job.setprogress(0.0)
    host("mkdir", "-p", target_models)
    completed = 0
    report = model_copy_reporter(total)
    for source in files:
        relative = source.relative_to(models)
        target = target_models / relative
        size = source.stat().st_size
        libcalamares.utils.debug(_("Copying {name}: {bytes} bytes ({gib:.2f} GiB) to {target}").format(
            name=str(relative), bytes=size, gib=size / 1024**3,
            target=str(models_directory / relative)))
        host("mkdir", "-p", target.parent)
        copy_model_file(source, target, completed, total, report)
        completed += size
        libcalamares.job.setprogress(min(0.99, completed / total))
    host("chmod", "-R", "u+rwX,go+rX,go-w", target_models)
    host("nixos-enter", "--root", root, "-c",
         "chown -R gufo:gufo /var/lib/gufo " + shlex.quote(str(models_directory)))
    libcalamares.job.setprogress(1.0)
    libcalamares.utils.debug(_("Model copying completed: {bytes} bytes in {count} files.").format(
        bytes=total, count=len(files)))


def pretty_name():
    stage = libcalamares.job.configuration.get("stage")
    if stage == "validate":
        return _("Preflight checks")
    if stage == "models":
        return _("Copy model weights")
    return _("Install NixOS")


def diagnostic_excerpt(path):
    """Best-effort display aid, never a replacement for original output."""
    if not path:
        return ""
    first_error = []
    tail = []
    remaining = 0
    try:
        with open(path, encoding="utf-8", errors="replace") as log:
            for raw in log:
                line = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", raw).rstrip()
                # Bound both individual lines and the displayed context.
                line = line[:500]
                tail = (tail + [line])[-8:]
                if remaining:
                    first_error.append(line)
                    remaining -= 1
                elif not first_error and "error:" in line.lower() and "cannot build" not in line.lower():
                    first_error = [line]
                    remaining = 7
                # Prefer an explicit download error over dependency cascades.
                # This selects text; it does not infer why the download failed.
                if "error:" in line.lower() and "unable to download" in line.lower():
                    return "\n".join(tail[-3:])
    except OSError:
        return ""
    return "\n".join(first_error or tail).strip()


def run():
    context = {"phase": _("Preflight checks")}
    started = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %z")
    # This stage runs after Calamares' partition and mount jobs, even if the
    # adapter's own validation fails before deployment starts.
    stage = libcalamares.job.configuration.get("stage", "validate")
    installation_started = stage in {"install", "models"}
    try:
        gs = libcalamares.globalstorage
        validate_selection(gs, libcalamares.job.configuration.get("withModels", True))
        if stage == "install":
            context["phase"] = _("Preparing system installation")
            deploy(gs, libcalamares.job.configuration, context)
        elif stage == "models":
            context["phase"] = _("Copying model weights")
            copy_models(gs, libcalamares.job.configuration, context)
        elif stage != "validate":
            raise ValueError(_("Invalid installer stage."))
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
        logger.error("Desktop installer: %s: %s", phase, detail)
        state = (
            _("NixOS has already been installed; model copying is incomplete. Do not reinstall or format the disk to retry the model copy.")
            if stage == "models" else
            _("The target disk has already been partitioned; installation is incomplete. Do not reinstall or format again without checking the disk first.")
            if installation_started else
            _("Preflight checks failed before partitioning.")
        )
        title = _("Model copying failed") if stage == "models" else _("NixOS installation failed")
        diagnostics_path = getattr(error, "diagnostics_path", None)
        excerpt = diagnostic_excerpt(diagnostics_path)
        original_error = (
            _("Original error excerpt (full output in the log):") + "\n" + excerpt + "\n\n"
            if excerpt else ""
        )
        diagnostics = (
            f"less {shlex.quote(diagnostics_path)}"
            if diagnostics_path else
            f"sudo journalctl -b --since '{started}' --no-pager"
        )
        return (title,
                 _("Phase: {phase}. {detail}").format(phase=phase, detail=detail) + f"\n\n{state}\n\n" +
                 original_error +
                _("Original diagnostics: Calamares output or in the live terminal:") + "\n" +
                diagnostics + "\n\n" +
                _("Check the first error before subsequent errors. Review logs for sensitive data before sharing; no automatic upload."))
