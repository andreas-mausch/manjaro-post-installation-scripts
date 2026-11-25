"""Test the Calamares adapter without running disk or installation commands."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

calamares = SimpleNamespace(
    utils=SimpleNamespace(obscure=lambda text: text),
    job=SimpleNamespace(setprogress=Mock(), configuration={"stage": "validate"}),
)
sys.modules["libcalamares"] = calamares
spec = importlib.util.spec_from_file_location("adapter", sys.argv.pop(1))
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class AdapterTests(unittest.TestCase):
    def storage(self, **changes):
        values = {
            "firmwareType": "efi", "username": "neonew",
            "password": "user-test-secret", "luksPassphrase": "luks-test-secret",
            "partitionChoices": {"install": "erase", "swap": "none"},
            "partitions": [
                {"mountPoint": "/", "fsName": "luks2", "fs": "btrfs"},
                {"mountPoint": "/boot", "fsName": "fat32", "fs": "fat32"},
            ],
            "rootMountPoint": "/tmp/calamares-root-test",
        } | changes
        return SimpleNamespace(value=values.get)

    def test_valid_selection(self):
        adapter.validate_selection(self.storage())

    def test_preflight_rejects_unsafe_or_unsupported_choices(self):
        for changes in [
            {"firmwareType": "bios"}, {"luksPassphrase": ""},
            {"luksPassphrase": "short"}, {"password": "short"},
            {"username": "gufo"}, {"username": "x\ny"},
            {"username": "root"}, {"autoLoginUser": "neonew"},
            {"partitionChoices": {"install": "manual", "swap": "none"}},
            {"partitionChoices": {"install": "erase", "swap": "small"}},
        ]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                adapter.validate_selection(self.storage(**changes))

    def test_preflight_never_runs_commands(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "validate"}
        with patch.object(adapter, "host") as host:
            self.assertIsNone(adapter.run())
            host.assert_not_called()

    def test_mount_validation_blocks_unencrypted_root_and_swap(self):
        for partitions in [
            [{"mountPoint": "/", "fsName": "ext4", "fs": "ext4"}],
            [{"mountPoint": "/", "fsName": "luks", "fs": "ext4"}],
            self.storage().value("partitions") + [{"fs": "linuxswap"}],
        ]:
            with self.assertRaises(ValueError), patch.object(adapter, "host") as host:
                adapter.validate_mounts(self.storage(partitions=partitions))
            host.assert_not_called()
        with self.assertRaises(ValueError):
            adapter.validate_mounts(self.storage(rootMountPoint="/"))

    def test_deployment_uses_flake_and_keeps_secrets_out_of_configuration(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            models = Path(temporary) / "models"
            source.mkdir()
            (source / "flake.lock").write_text("{}")
            (models / "flash-next-q4").mkdir(parents=True)
            config = {"source": str(source), "models": str(models), "offline": True}
            with (
                patch.object(adapter, "host", return_value=SimpleNamespace(stdout="hardware")) as host,
                patch.object(adapter.subprocess, "run", return_value=SimpleNamespace(stdout="$y$hash\n")) as run,
            ):
                adapter.deploy(self.storage(), config)
            commands = [tuple(map(str, call.args)) for call in host.call_args_list]
            install = next(command for command in commands if "nixos-install" in command)
            self.assertEqual(install[:4], ("unshare", "--net", "--", "nixos-install"))
            self.assertIn("substituters", install)
            self.assertIn("builders", install)
            self.assertIn("flake-registry", install)
            self.assertIn("path:/tmp/calamares-root-test/etc/nixos#m5", install)
            self.assertIn("--no-update-lock-file", install)
            # This suppresses a terminal prompt; NixOS separately locks root.
            self.assertIn("--no-root-passwd", install)
            self.assertIn("--show-hardware-config", " ".join(map(str, commands)))
            self.assertTrue(any(command[:2] == ("cp", "-rL") for command in commands))
            self.assertNotIn("user-test-secret", str(commands))
            self.assertNotIn("luks-test-secret", str(commands))
            self.assertEqual(run.call_args.kwargs["input"], "user-test-secret\n")
            identity_call = next(call for call in host.call_args_list
                                 if call.args[0] == "tee" and str(call.args[1]).endswith("installation.json"))
            data = json.loads(identity_call.kwargs["input"])
            self.assertEqual(data["username"], "neonew")
            self.assertNotIn("password", data)
            hash_call = next(call for call in host.call_args_list
                             if call.args[0] == "tee" and str(call.args[1]).endswith("user-password.hash"))
            self.assertEqual(hash_call.kwargs["input"], "$y$hash\n")

    def test_failures_do_not_expose_subprocess_input(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        with patch.object(adapter, "deploy", side_effect=subprocess.CalledProcessError(1, ["secret"])):
            result = adapter.run()
        self.assertIsInstance(result, tuple)
        self.assertNotIn("secret", str(result))


if __name__ == "__main__":
    unittest.main()
