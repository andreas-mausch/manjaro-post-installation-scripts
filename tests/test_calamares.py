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
    utils=SimpleNamespace(obscure=lambda text: text, gettext_languages=lambda: ["en"]),
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
            "packagechooser_models": "qwen",
        } | changes
        return SimpleNamespace(value=values.get)

    def test_valid_selection(self):
        adapter.validate_selection(self.storage())

    def test_selection_accepts_optional_encryption_and_native_passphrase_policy(self):
        for passphrase in [None, "", "short", "luks-test-secret"]:
            with self.subTest(passphrase=passphrase):
                adapter.validate_selection(self.storage(luksPassphrase=passphrase))

    def test_mount_validation_accepts_different_root_filesystems(self):
        for fs_name, fs in [("btrfs", "btrfs"), ("luks2", "btrfs"), ("ext4", "ext4")]:
            partitions = [
                {"mountPoint": "/", "fsName": fs_name, "fs": fs},
                {"mountPoint": "/boot", "fsName": "fat32", "fs": "fat32"},
            ]
            with self.subTest(fs_name=fs_name), patch.object(adapter, "host"):
                adapter.validate_mounts(self.storage(partitions=partitions))

    def test_preflight_rejects_unsafe_or_unsupported_choices(self):
        for changes in [
            {"packagechooser_models": None}, {"packagechooser_models": "unexpected"},
            {"firmwareType": "bios"},
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

    def test_selection_does_not_duplicate_native_user_password_validation(self):
        adapter.validate_selection(self.storage(password="short"))

    def test_mount_validation_blocks_invalid_layouts_and_swap(self):
        for partitions in [
            self.storage().value("partitions")[1:],
            self.storage().value("partitions") + [{"mountPoint": "/", "fs": "ext4"}],
            [{"mountPoint": "/", "fsName": "ext4", "fs": "ext4"}],
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
            config = {"source": str(source), "models": str(models)}
            with (
                patch.object(adapter, "host", return_value=SimpleNamespace(stdout="hardware")) as host,
                patch.object(adapter.subprocess, "run", return_value=SimpleNamespace(stdout="$y$hash\n")) as run,
            ):
                adapter.deploy(self.storage(), config)
            commands = [tuple(map(str, call.args)) for call in host.call_args_list]
            install = next(command for command in commands if "nixos-install" in command)
            self.assertEqual(install[0], "nixos-install")
            self.assertNotIn("unshare", install)
            self.assertNotIn("substituters", install)
            self.assertNotIn("builders", install)
            self.assertNotIn("flake-registry", install)
            options = {
                install[index + 1]: install[index + 2]
                for index, argument in enumerate(install) if argument == "--option"
            }
            self.assertEqual(options["substitute"], "true")
            self.assertEqual(options["always-allow-substitutes"], "true")
            self.assertNotIn("require-sigs", options)
            for call in host.call_args_list:
                if call.args[0] == "tee":
                    self.assertNotIn("always-allow-substitutes", call.kwargs.get("input", ""))
                    self.assertNotIn("alwaysAllowSubstitutes", call.kwargs.get("input", ""))
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

    def test_deployment_without_models_still_installs_system(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            models = Path(temporary) / "models"
            source.mkdir()
            (source / "flake.lock").write_text("{}")
            (models / "flash-next-q4").mkdir(parents=True)
            with (
                patch.object(adapter, "host", return_value=SimpleNamespace(stdout="hardware")) as host,
                patch.object(adapter.subprocess, "run", return_value=SimpleNamespace(stdout="$y$hash\n")),
            ):
                adapter.deploy(self.storage(packagechooser_models="without-models"),
                               {"source": str(source), "models": str(models)})
            commands = [tuple(map(str, call.args)) for call in host.call_args_list]
            self.assertTrue(any("nixos-install" in command for command in commands))
            self.assertFalse(any(command[:2] == ("cp", "-rL") for command in commands))
            self.assertFalse(any("/var/lib/gufo/models" in " ".join(command) for command in commands))

    def test_failures_do_not_expose_subprocess_input(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        with patch.object(adapter, "deploy", side_effect=subprocess.CalledProcessError(1, ["secret"])):
            result = adapter.run()
        self.assertIsInstance(result, tuple)
        self.assertNotIn("secret", str(result))

    def test_validation_failure_reports_specific_reason(self):
        calamares.globalstorage = self.storage(firmwareType="bios")
        calamares.job.configuration = {"stage": "validate"}
        with self.assertLogs("m5-installer", level="ERROR") as logs:
            result = adapter.run()
        self.assertIn("UEFI", result[1])
        self.assertIn("Preflight checks", result[1])
        self.assertIn("UEFI", " ".join(logs.output))
        self.assertIn("before partitioning", result[1])
        self.assertIn("sudo journalctl -b --since", result[1])

    def test_installation_failure_reports_phase_and_partitioned_state(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}

        def fail(gs, config, context):
            context["phase"] = adapter._("Offline system installation")
            raise subprocess.CalledProcessError(1, ["pkexec", "unshare", "--net", "--", "nixos-install"])

        with patch.object(adapter, "deploy", side_effect=fail), self.assertLogs("m5-installer"):
            result = adapter.run()
        self.assertIn("Phase: Offline system installation", result[1])
        self.assertIn("System installation command failed", result[1])
        self.assertNotIn("unshare failed", result[1])
        self.assertIn("already been partitioned", result[1])

    def test_install_stage_preflight_failure_still_warns_about_partitioning(self):
        calamares.globalstorage = self.storage(username="root")
        calamares.job.configuration = {"stage": "install"}
        with self.assertLogs("m5-installer"), patch.object(adapter, "deploy") as deploy:
            result = adapter.run()
        deploy.assert_not_called()
        self.assertIn("already been partitioned", result[1])

    def test_host_preserves_original_diagnostics_without_logging_arguments(self):
        with patch.object(adapter.subprocess, "run") as run, self.assertLogs("m5-installer") as logs:
            adapter.host("cp", "secret-argument")
        self.assertIsNone(run.call_args.kwargs["stdout"])
        self.assertNotIn("stderr", run.call_args.kwargs)
        self.assertNotIn("secret-argument", str(logs.output))

    def test_command_failure_reports_program_and_exit_code_without_secrets(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        error = subprocess.CalledProcessError(17, ["pkexec", "cp", "secret-argument"],
                                             output="secret-output", stderr="secret-stderr")
        with patch.object(adapter, "deploy", side_effect=error), self.assertLogs("m5-installer") as logs:
            result = adapter.run()
        self.assertIn("cp failed (exit code 17)", result[1])
        self.assertNotIn("secret", str(result) + str(logs.output))

    def test_os_failure_does_not_expose_filename(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        with patch.object(adapter, "deploy", side_effect=OSError(2, "secret", "secret-path")), self.assertLogs("m5-installer") as logs:
            result = adapter.run()
        self.assertIn("errno 2", result[1])
        self.assertNotIn("secret", str(result) + str(logs.output))


if __name__ == "__main__":
    unittest.main()
