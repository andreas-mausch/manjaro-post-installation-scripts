"""Evaluate writable installed archives; no disks, VMs or privileged commands.

Usage: python tests/test_installed_flakes.py VARIANT ARCHIVE [VARIANT ARCHIVE ...]
"""
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace

sys.modules["libcalamares"] = SimpleNamespace()
spec = importlib.util.spec_from_file_location(
    "adapter", Path(__file__).parents[1] / "modules/installer/calamares/main.py",
)
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def evaluate(path, target, expression):
    return json.loads(subprocess.check_output([
        "nix", "eval", "--offline", "--json",
        f"path:{path}#nixosConfigurations.{target}.config",
        "--apply", expression,
    ], text=True))


def check(variant, archive):
    with tempfile.TemporaryDirectory(prefix=f"installed-{variant}-") as temporary:
        source = Path(temporary) / "source"
        shutil.copytree(archive, source, symlinks=True)
        for path in [source, *source.rglob("*")]:
            if not path.is_symlink():
                path.chmod(path.stat().st_mode | 0o200)
        identity = {
            "username": "vmuser", "fullname": 'A "quoted" ${literal} name',
            "hostname": "workstation", "timezone": "UTC", "locale": "en_US.UTF-8",
            "keyboardLayout": "us", "keyboardVariant": "", "consoleKeyMap": "us",
            "variant": variant,
        }
        (source / "installation.json").write_text(json.dumps(identity))
        (source / "hardware-configuration.nix").write_text('''{ ... }: {
  fileSystems."/" = { device = "/dev/disk/by-uuid/test-root"; fsType = "btrfs"; };
  fileSystems."/boot" = { device = "/dev/disk/by-uuid/test-efi"; fsType = "vfat"; };
}
''')
        configuration = adapter.local_configuration(identity).replace(
            "  # Compatibility", "  services.spice-vdagentd.enable = true;\n\n  # Compatibility",
        )
        (source / "configuration.nix").write_text(configuration)
        expression = '''c: {
          hostname = c.networking.hostName;
          timezone = c.time.timeZone;
          locale = c.i18n.defaultLocale;
          keyboard = c.services.xserver.xkb.layout;
          root = c.fileSystems."/".device;
          spice = c.services.spice-vdagentd.enable;
          user = c.users.users.vmuser;
          dummyUser = c.users.users ? desktopuser;
          stateVersion = c.system.stateVersion;
          steam = c.programs.steam.enable;
          gufo = c.systemd.services ? gufo;
        }'''
        config = evaluate(source, "workstation", expression)
        assert config == evaluate(source, variant, expression), variant
        assert config["hostname"] == "workstation"
        assert config["timezone"] == "UTC"
        assert config["locale"] == "en_US.UTF-8"
        assert config["keyboard"] == "us"
        assert config["root"] == "/dev/disk/by-uuid/test-root"
        assert config["spice"] and not config["dummyUser"]
        assert config["user"]["description"] == identity["fullname"]
        assert config["user"]["hashedPasswordFile"] == "/var/lib/nixos-secrets/user-password.hash"
        assert config["stateVersion"] == "26.05"
        assert config["steam"] == (variant in {"gaming", "full"})
        assert config["gufo"] == (variant in {"ai", "full"})
        # The alias follows configuration.nix, not stale installation metadata.
        (source / "configuration.nix").write_text(configuration.replace(
            'networking.hostName = "workstation";', 'networking.hostName = "renamed-host";',
        ))
        assert evaluate(source, "renamed-host", "c: c.networking.hostName") == "renamed-host"
        print(f"{variant}: local settings, hardware, user, variant and hostname alias OK")


if __name__ == "__main__":
    if len(sys.argv) < 3 or len(sys.argv) % 2 != 1:
        raise SystemExit(__doc__)
    for index in range(1, len(sys.argv), 2):
        check(sys.argv[index], sys.argv[index + 1])
