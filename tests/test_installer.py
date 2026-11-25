"""Safety/validation tests; never execute the installer or disk commands."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

spec = importlib.util.spec_from_file_location("installer", sys.argv.pop(1))
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def test_usernames(self):
        for name in ["neonew", "a", "user_1", "user-name"]:
            self.assertTrue(installer.valid_username(name), name)
        for name in ["root", "gufo", "nobody", "", "A", "a/b", "a\nb", "1user", "a" * 32]:
            self.assertFalse(installer.valid_username(name), name)

    def disk(self, **changes):
        return dict(type="disk", tran="nvme", rm=False, ro=False,
                    size=2 * 1024**4, mountpoints=[None], children=[], **changes)

    def test_disk_eligibility(self):
        disk = self.disk()
        self.assertTrue(installer.eligible_disk(disk))
        for key, value in [("tran", "usb"), ("rm", True), ("ro", True),
                           ("size", 100), ("type", "part"), ("mountpoints", ["/mnt"])]:
            self.assertFalse(installer.eligible_disk(disk | {key: value}))

    def test_mounted_descendants_are_excluded(self):
        disk = self.disk()
        child = {"mountpoints": [None], "children": [{"mountpoints": ["/iso"]}]}
        self.assertFalse(installer.eligible_disk(disk | {"children": [child]}))

    def test_partition_names(self):
        self.assertEqual(installer.partition("/dev/nvme0n1", 2), "/dev/nvme0n1p2")
        self.assertEqual(installer.partition("/dev/sda", 1), "/dev/sda1")

    def test_configuration_copy_excludes_local_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            source.mkdir()
            for name in ["flake.nix", "flake.lock", "installation.json", "hardware-configuration.nix"]:
                (source / name).write_text("test")
            (source / ".git").mkdir()
            destination = Path(temporary) / "destination"
            installer.copy_configuration(source, destination)
            self.assertEqual({p.name for p in destination.iterdir()}, {"flake.nix", "flake.lock"})

    def test_wrong_confirmation_never_calls_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            (Path(temporary) / "flake.lock").write_text("{}")
            disk = self.disk() | {"path": "/dev/nvme0n1"}
            with (
                patch.object(sys, "argv", ["install-m5"]),
                patch.dict(installer.os.environ, {"M5_SOURCE": temporary, "M5_GUFO": "/gufo"}),
                patch.object(installer.os, "geteuid", return_value=0),
                patch.object(Path, "is_dir", return_value=True),
                patch.object(installer, "list_disks", return_value=[disk]),
                patch.object(installer, "ask_secret", return_value="test-not-a-real-secret"),
                patch("builtins.input", side_effect=["n", "1", "neonew", "wrong"]),
                patch.object(installer, "run", return_value=Mock(stdout="$y$test")) as run,
                patch.object(installer, "install") as install,
            ):
                installer.main()
                install.assert_not_called()
                self.assertEqual([call.args[0] for call in run.call_args_list], ["nm-online", "mkpasswd"])

    def test_existing_mount_blocks_installation(self):
        with (
            patch.object(installer.os.path, "ismount", return_value=True),
            patch.object(installer, "run") as run,
        ):
            with self.assertRaises(RuntimeError):
                installer.install("/dev/nvme0n1", "neonew", "hash", "key", Path("/source"), "/gufo")
            run.assert_not_called()

    def test_disk_recheck_blocks_all_writes(self):
        with (
            patch.object(installer.os.path, "ismount", return_value=False),
            patch.object(Path, "exists", return_value=False),
            patch.object(installer, "list_disks", return_value=[]),
            patch.object(installer, "run") as run,
        ):
            with self.assertRaises(RuntimeError):
                installer.install("/dev/nvme0n1", "neonew", "hash", "key", Path("/source"), "/gufo")
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
