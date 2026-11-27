"""Test the Calamares adapter without running disk or installation commands."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import ANY, Mock, patch

calamares = SimpleNamespace(
    utils=SimpleNamespace(obscure=lambda text: text, gettext_languages=lambda: ["en"],
                          host_env_process_output=Mock(), debug=Mock()),
    job=SimpleNamespace(setprogress=Mock(), configuration={"stage": "validate"}),
)
sys.modules["libcalamares"] = calamares
spec = importlib.util.spec_from_file_location("adapter", sys.argv.pop(1))
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class AdapterTests(unittest.TestCase):
    def setUp(self):
        # Repository transport is tested separately from disk deployment.
        patcher = patch.object(adapter, "provision_repository")
        self.provision_repository = patcher.start()
        self.addCleanup(patcher.stop)

    def storage(self, **changes):
        values = {
            "firmwareType": "efi", "username": "testuser", "hostname": "nixos-desktop",
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

    def test_identity_requires_hostname_from_calamares(self):
        for hostname in [None, "", "   "]:
            with self.subTest(hostname=hostname), self.assertRaisesRegex(ValueError, "did not provide a hostname"):
                adapter.identity(self.storage(hostname=hostname))

    def test_spice_guest_integration_is_optional_local_configuration(self):
        installation = adapter.identity(self.storage())
        self.assertNotIn("spice-vdagentd", adapter.local_configuration(installation))
        self.assertIn("services.spice-vdagentd.enable = true;",
                      adapter.local_configuration(installation, spice=True))

    def test_timezone_is_mutable_only_for_desktop_profiles(self):
        for variant in ["base", "desktop", "gaming", "ai", "full"]:
            installation = adapter.identity(self.storage()) | {"variant": variant}
            value = '"Europe/Berlin"' if variant == "base" else "null"
            self.assertIn(f"time.timeZone = {value};", adapter.local_configuration(installation))

    def test_ssh_is_opt_in_and_uses_build_supplied_key_file(self):
        installation = adapter.identity(self.storage())
        self.assertNotIn("openssh", adapter.local_configuration(installation))
        enabled = adapter.local_configuration(installation, ssh=True)
        self.assertIn("services.openssh.enable = true;", enabled)
        self.assertIn('users.users."testuser".openssh.authorizedKeys.keyFiles', enabled)
        self.assertIn("./ssh-authorized-keys", enabled)
        self.assertNotIn("PasswordAuthentication = true", enabled)

    def test_deployment_honors_ssh_selection(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder)
            (source / "flake.lock").write_text("{}")
            for choice in [None, "", "ssh"]:
                with self.subTest(choice=choice), \
                        patch.object(adapter, "host", return_value=SimpleNamespace(stdout="hardware")) as host, \
                        patch.object(adapter.subprocess, "run", return_value=SimpleNamespace(stdout="$y$hash\n")):
                    adapter.deploy(self.storage(packagechooser_ssh=choice), {"source": folder, "repositoryRemote": "https://example.invalid/setup.git"})
                    configuration = next(call.kwargs["input"] for call in host.call_args_list
                                         if call.args[0] == "tee" and str(call.args[1]).endswith("/configuration.nix"))
                    self.assertEqual("services.openssh.enable = true;" in configuration, choice == "ssh")

    def test_non_ai_preflight_needs_no_model_selection(self):
        calamares.globalstorage = self.storage(packagechooser_models=None)
        calamares.job.configuration = {"stage": "validate", "withModels": False}
        with patch.object(adapter, "host") as host:
            self.assertIsNone(adapter.run())
        host.assert_not_called()
        with self.assertRaises(ValueError):
            adapter.validate_selection(self.storage(firmwareType="bios"), with_models=False)

    def test_each_variant_deploys_hostname_target_and_records_variant(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            (source / "flake.lock").write_text("{}")
            for variant in ["base", "desktop", "gaming", "ai", "full"]:
                with self.subTest(variant=variant), \
                        patch.object(adapter, "host", return_value=SimpleNamespace(stdout="hardware")) as host, \
                        patch.object(adapter.subprocess, "run", return_value=SimpleNamespace(stdout="$y$hash\n")):
                    adapter.deploy(self.storage(packagechooser_models=None, hostname="workstation"),
                                   {"source": str(source), "target": variant, "withModels": False, "repositoryRemote": "https://example.invalid/setup.git"})
                    command = next(call.args for call in host.call_args_list if call.args[0] == "nixos-install")
                    self.assertIn("path:/tmp/calamares-root-test/etc/nixos#workstation", command)
                    identity_call = next(call for call in host.call_args_list
                                         if call.args[0] == "tee" and str(call.args[1]).endswith("installation.json"))
                    self.assertEqual(json.loads(identity_call.kwargs["input"])["variant"], variant)
                    timezone_calls = [call for call in host.call_args_list
                                      if call.args[0] == "ln" and str(call.args[-1]).endswith("/etc/localtime")]
                    self.assertEqual(len(timezone_calls), 0 if variant == "base" else 1)
                    if timezone_calls:
                        self.assertEqual(timezone_calls[0].args[2], "/etc/zoneinfo/Europe/Berlin")

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
            {"username": "root"}, {"autoLoginUser": "testuser"},
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
            config = {"source": str(source), "repositoryRemote": "https://example.invalid/setup.git"}
            with (
                patch.object(adapter, "host", return_value=SimpleNamespace(stdout="hardware")) as host,
                patch.object(adapter.subprocess, "run", return_value=SimpleNamespace(stdout="$y$hash\n")) as run,
            ):
                adapter.deploy(self.storage(), config)
            commands = [tuple(map(str, call.args)) for call in host.call_args_list]
            install = next(command for command in commands if "nixos-install" in command)
            self.assertEqual(install[0], "nixos-install")
            preserve = next(command for command in commands if command[0] == "nixos-enter")
            self.assertEqual(preserve[1:4], ("--root", "/tmp/calamares-root-test", "-c"))
            self.assertIn("readlink -e /nix/var/nix/profiles/system", preserve[4])
            self.assertIn("--add-root /nix/var/nix/gcroots/nixos-install", preserve[4])
            self.assertNotIn("/run/current-system", preserve[4])
            self.assertGreater(commands.index(preserve), commands.index(install))
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
                self.assertEqual(call.kwargs.get("stream", False), call.args[0] == "nixos-install")
                if call.args[0] == "tee":
                    self.assertNotIn("always-allow-substitutes", call.kwargs.get("input", ""))
                    self.assertNotIn("alwaysAllowSubstitutes", call.kwargs.get("input", ""))
            self.assertIn("path:/tmp/calamares-root-test/etc/nixos#nixos-desktop", install)
            self.assertIn("--no-update-lock-file", install)
            # This suppresses a terminal prompt; NixOS separately locks root.
            self.assertIn("--no-root-passwd", install)
            self.assertIn("--show-hardware-config", " ".join(map(str, commands)))
            self.assertFalse(any(command[:2] == ("cp", "-rL") for command in commands))
            self.assertNotIn("user-test-secret", str(commands))
            self.assertNotIn("luks-test-secret", str(commands))
            self.assertEqual(run.call_args.kwargs["input"], "user-test-secret\n")
            identity_call = next(call for call in host.call_args_list
                                 if call.args[0] == "tee" and str(call.args[1]).endswith("installation.json"))
            data = json.loads(identity_call.kwargs["input"])
            self.assertEqual(data["username"], "testuser")
            self.assertNotIn("password", data)
            configuration_call = next(call for call in host.call_args_list
                                      if call.args[0] == "tee" and str(call.args[1]).endswith("/configuration.nix"))
            configuration = configuration_call.kwargs["input"]
            self.assertIn("imports = [ ./hardware-configuration.nix ];", configuration)
            self.assertIn('users.users."testuser"', configuration)
            self.assertIn('networking.hostName = "nixos-desktop";', configuration)
            self.assertIn('system.stateVersion = "26.05";', configuration)
            self.assertNotIn("user-test-secret", configuration)
            self.assertNotIn("$y$hash", configuration)
            hash_call = next(call for call in host.call_args_list
                             if call.args[0] == "tee" and str(call.args[1]).endswith("user-password.hash"))
            self.assertEqual(hash_call.kwargs["input"], "$y$hash\n")

    def test_local_configuration_escapes_nix_interpolation_and_quotes(self):
        installation = adapter.identity(self.storage(fullname='A "quoted" ${builtins.abort "oops"} name'))
        configuration = adapter.local_configuration(installation)
        self.assertIn('\\${builtins.abort', configuration)
        self.assertIn('\\"quoted\\"', configuration)

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
                                {"source": str(source), "models": str(models), "repositoryRemote": "https://example.invalid/setup.git"})
            commands = [tuple(map(str, call.args)) for call in host.call_args_list]
            identity_call = next(call for call in host.call_args_list
                                 if call.args[0] == "tee" and str(call.args[1]).endswith("installation.json"))
            self.assertEqual(json.loads(identity_call.kwargs["input"])["hostname"], "nixos-desktop")
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

    def test_model_job_copies_weights_without_installing_system(self):
        with tempfile.TemporaryDirectory() as temporary:
            models = Path(temporary) / "models"
            (models / "flash-next-q4").mkdir(parents=True)
            (models / "flash-next-q4/weights.gguf").write_bytes(b"weights")
            calamares.globalstorage = self.storage()
            calamares.job.configuration = {"stage": "models", "models": str(models),
                                           "modelsDirectory": "/var/lib/generative-ai/models"}
            with patch.object(adapter, "host") as host, patch.object(adapter, "deploy") as deploy, \
                    patch.object(adapter, "copy_model_file") as copy, \
                    patch.object(calamares.utils, "debug") as debug, \
                    patch.object(calamares.job, "setprogress") as progress:
                self.assertIsNone(adapter.run())
            commands = [tuple(map(str, call.args)) for call in host.call_args_list]
            copy.assert_called_once_with(models / "flash-next-q4/weights.gguf",
                                         Path("/tmp/calamares-root-test/var/lib/generative-ai/models/flash-next-q4/weights.gguf"),
                                 0, 7, ANY)
            messages = [call.args[0] for call in debug.call_args_list]
            self.assertIn("1 model files: 7 bytes", messages[0])
            self.assertIn("flash-next-q4/weights.gguf", messages[1])
            self.assertIn("/var/lib/generative-ai/models/flash-next-q4/weights.gguf", messages[1])
            self.assertNotIn("/tmp/calamares", str(messages))
            self.assertIn("Model copying completed", messages[2])
            self.assertEqual([call.args[0] for call in progress.call_args_list], [0.0, 0.99, 1.0])
            self.assertTrue(any(command[0] == "nixos-enter" for command in commands))
            self.assertFalse(any(command[0] == "nixos-install" for command in commands))
            deploy.assert_not_called()

    def test_model_copy_progress_tracks_bytes_and_propagates_failure(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            target = Path(temporary) / "target"
            source.write_bytes(b"12345678")
            target.write_bytes(b"1234")
            for exit_code in [0, 17]:
                with self.subTest(exit_code=exit_code), patch.object(adapter, "host"), \
                        patch.object(adapter.subprocess, "Popen") as popen, \
                        patch.object(calamares.job, "setprogress") as progress:
                    popen.return_value.__enter__.return_value.wait.side_effect = [
                        subprocess.TimeoutExpired("cp", 0.25), exit_code]
                    if exit_code:
                        with self.assertRaises(subprocess.CalledProcessError) as raised:
                            adapter.copy_model_file(source, target, 8, 16)
                        self.assertEqual(raised.exception.returncode, exit_code)
                    else:
                        adapter.copy_model_file(source, target, 8, 16)
                    progress.assert_called_once_with(0.75)

    def test_model_copy_speed_reports_every_three_seconds_across_files(self):
        mib = 1024**2
        with patch.object(adapter.time, "monotonic", side_effect=[10, 12.9, 13, 15.9, 16]), \
                patch.object(calamares.utils, "debug") as debug:
            report = adapter.model_copy_reporter(1024 * mib)
            report(2 * mib)
            debug.assert_not_called()
            report(6 * mib)
            self.assertIn("2.0 MiB/s", debug.call_args.args[0])
            report(9 * mib)
            self.assertEqual(debug.call_count, 1)
            report(9 * mib)
            self.assertEqual(debug.call_count, 2)
            self.assertIn("1.0 MiB/s", debug.call_args.args[0])

    def test_model_copy_speed_reports_stalls(self):
        with patch.object(adapter.time, "monotonic", side_effect=[0, 3, 6]), \
                patch.object(calamares.utils, "debug") as debug:
            report = adapter.model_copy_reporter(1024**3)
            report(3 * 1024**2)
            report(3 * 1024**2)
            self.assertIn("0.0 MiB/s", debug.call_args.args[0])

    def test_model_directory_controls_copy_target_logs_and_ownership(self):
        with tempfile.TemporaryDirectory() as temporary:
            models = Path(temporary)
            (models / "flash-next-q4").mkdir()
            (models / "flash-next-q4/weights.gguf").write_bytes(b"weights")
            with patch.object(adapter, "host") as host, \
                    patch.object(adapter, "copy_model_file") as copy, \
                    patch.object(calamares.utils, "debug") as debug:
                adapter.copy_models(self.storage(), {"models": temporary,
                                    "modelsDirectory": "/srv/ai/models"}, {})
            self.assertEqual(copy.call_args.args[1],
                             Path("/tmp/calamares-root-test/srv/ai/models/flash-next-q4/weights.gguf"))
            self.assertIn("/srv/ai/models", debug.call_args_list[0].args[0])
            self.assertIn("/srv/ai/models", host.call_args.args[-1])

    def test_model_copy_preserves_task_model_and_hf_layout_through_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            weights = base / "weights"
            weights.mkdir()
            (weights / "shard.gguf").write_bytes(b"weights")
            models = base / "models"
            qwen = models / "text-generation/Qwen3.8-Flash-Next"
            qwen.mkdir(parents=True)
            (qwen / "UD-Q4_K_XL").symlink_to(weights, target_is_directory=True)
            with patch.object(adapter, "host"), patch.object(adapter, "copy_model_file") as copy:
                adapter.copy_models(self.storage(), {"models": str(models),
                                    "modelsDirectory": "/var/lib/generative-ai/models"}, {})
            self.assertEqual(copy.call_args.args[1], Path(
                "/tmp/calamares-root-test/var/lib/generative-ai/models/"
                "text-generation/Qwen3.8-Flash-Next/UD-Q4_K_XL/shard.gguf"))

    def test_model_job_without_weights_does_nothing(self):
        calamares.globalstorage = self.storage(packagechooser_models="without-models")
        calamares.job.configuration = {"stage": "models"}
        with patch.object(adapter, "host") as host, patch.object(adapter, "deploy") as deploy:
            self.assertIsNone(adapter.run())
        host.assert_not_called()
        deploy.assert_not_called()

    def test_model_failure_warns_against_reinstallation(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "models"}
        with patch.object(adapter, "copy_models", side_effect=subprocess.CalledProcessError(1, ["cp"])), \
                self.assertLogs("desktop-installer"):
            result = adapter.run()
        self.assertEqual(result[0], "Model copying failed")
        self.assertIn("NixOS has already been installed", result[1])
        self.assertIn("Do not reinstall", result[1])

    def test_model_job_rejects_missing_weights_before_copying(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(adapter, "host") as host:
            with self.assertRaisesRegex(ValueError, "Model weights are missing"):
                adapter.copy_models(self.storage(), {"models": temporary,
                                    "modelsDirectory": "/var/lib/generative-ai/models"}, {})
        self.assertFalse(any(call.args[0] == "cp" for call in host.call_args_list))

    def test_job_titles_are_stage_specific(self):
        for stage, title in (("validate", "Preflight checks"), ("install", "Install NixOS"),
                             ("models", "Copy model weights")):
            with self.subTest(stage=stage):
                calamares.job.configuration = {"stage": stage}
                self.assertEqual(adapter.pretty_name(), title)

    def test_validation_failure_reports_specific_reason(self):
        calamares.globalstorage = self.storage(firmwareType="bios")
        calamares.job.configuration = {"stage": "validate"}
        with self.assertLogs("desktop-installer", level="ERROR") as logs:
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

        with patch.object(adapter, "deploy", side_effect=fail), self.assertLogs("desktop-installer"):
            result = adapter.run()
        self.assertIn("Phase: Offline system installation", result[1])
        self.assertIn("System installation command failed", result[1])
        self.assertNotIn("unshare failed", result[1])
        self.assertIn("already been partitioned", result[1])

    def test_install_stage_preflight_failure_still_warns_about_partitioning(self):
        calamares.globalstorage = self.storage(username="root")
        calamares.job.configuration = {"stage": "install"}
        with self.assertLogs("desktop-installer"), patch.object(adapter, "deploy") as deploy:
            result = adapter.run()
        deploy.assert_not_called()
        self.assertIn("already been partitioned", result[1])

    def test_host_preserves_original_diagnostics_without_logging_arguments(self):
        with patch.object(adapter.subprocess, "run") as run, self.assertLogs("desktop-installer") as logs:
            adapter.host("cp", "secret-argument")
        self.assertIsNone(run.call_args.kwargs["stdout"])
        self.assertNotIn("stderr", run.call_args.kwargs)
        self.assertNotIn("secret-argument", str(logs.output))

    def test_write_file_captures_echoed_contents(self):
        with patch.object(adapter.subprocess, "run") as run:
            adapter.write_file("/target/user-password.hash", "$y$secret\n", "0600")
        self.assertEqual(run.call_args.args[0], ["pkexec", "tee", "/target/user-password.hash"])
        self.assertEqual(run.call_args.kwargs["input"], "$y$secret\n")
        self.assertEqual(run.call_args.kwargs["stdout"], subprocess.PIPE)

    def test_host_streams_through_calamares_without_timeout(self):
        with patch.object(calamares.utils, "host_env_process_output") as process, \
                patch.object(adapter.subprocess, "run") as run:
            adapter.host("nixos-install", "--root", Path("/mnt"), stream=True)
        self.assertEqual(process.call_args.args[0], ["pkexec", "nixos-install", "--root", "/mnt"])
        self.assertTrue(callable(process.call_args.args[1]))
        self.assertEqual(process.call_args.args[2:], ("", 0))
        run.assert_not_called()

    def test_streamed_output_reaches_calamares_logger_during_execution(self):
        def emit_output(command, callback, stdin, timeout):
            callback("building the configuration...")
            callback("installing the boot loader...")
            return 0

        with patch.object(calamares.utils, "debug") as debug, \
                patch.object(calamares.utils, "host_env_process_output", side_effect=emit_output):
            self.assertEqual(adapter.host("nixos-install", stream=True), 0)
        self.assertEqual([call.args[0] for call in debug.call_args_list],
                         ["building the configuration...", "installing the boot loader..."])

    def test_streaming_failure_preserves_exit_code(self):
        error = subprocess.CalledProcessError(17, ["pkexec", "nixos-install"])
        with patch.object(calamares.utils, "host_env_process_output", side_effect=error):
            with self.assertRaises(subprocess.CalledProcessError) as raised:
                adapter.host("nixos-install", stream=True)
        self.assertEqual(raised.exception.returncode, 17)
        self.assertEqual(raised.exception.cmd, ["pkexec", "nixos-install"])
        self.assertTrue(Path(raised.exception.diagnostics_path).is_file())

    def test_stream_failure_retains_original_output_in_private_log(self):
        def fail(command, callback, stdin, timeout):
            callback("error: unable to download source")
            raise subprocess.CalledProcessError(1, [])

        with patch.object(calamares.utils, "host_env_process_output", side_effect=fail):
            with self.assertRaises(subprocess.CalledProcessError) as raised:
                adapter.host("nixos-install", stream=True)
        log = Path(raised.exception.diagnostics_path)
        self.assertEqual(log.read_text(), "error: unable to download source\n")
        self.assertEqual(log.stat().st_mode & 0o777, 0o600)

    def test_failure_dialog_points_to_saved_output(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        error = subprocess.CalledProcessError(1, ["pkexec", "nixos-install"])
        error.diagnostics_path = "/tmp/desktop-install-test.log"
        with patch.object(adapter, "deploy", side_effect=error):
            title, detail = adapter.run()
        self.assertIn("less /tmp/desktop-install-test.log", detail)
        self.assertNotIn("sudo journalctl", detail)

    def test_excerpt_prefers_download_error_without_changing_log(self):
        text = "error: Cannot build dependency\nLast log lines:\n> error:\n> error: unable to download 'https://example.org': Could not resolve host\nReason: 1 dependency failed\n"
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / "install.log"
            log.write_text(text)
            excerpt = adapter.diagnostic_excerpt(log)
            self.assertIn("Could not resolve host", excerpt)
            self.assertNotIn("1 dependency failed", excerpt)
            self.assertEqual(log.read_text(), text)

    def test_excerpt_is_bounded_and_missing_logs_are_safe(self):
        self.assertEqual(adapter.diagnostic_excerpt(None), "")
        self.assertEqual(adapter.diagnostic_excerpt("/nonexistent/install.log"), "")
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / "install.log"
            log.write_text("\x1b[31merror: original failure\x1b[0m\n" + ("x" * 1000 + "\n") * 100)
            excerpt = adapter.diagnostic_excerpt(log)
            self.assertNotIn("\x1b", excerpt)
            self.assertLessEqual(len(excerpt.splitlines()), 8)
            self.assertLessEqual(max(map(len, excerpt.splitlines())), 500)

    def test_streaming_rejects_input_and_capture(self):
        for options in ({"input": "secret"}, {"capture": True}):
            with self.subTest(options=options), \
                    patch.object(calamares.utils, "host_env_process_output") as process:
                with self.assertRaises(ValueError):
                    adapter.host("tee", stream=True, **options)
                process.assert_not_called()

    def test_command_failure_reports_program_and_exit_code_without_secrets(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        error = subprocess.CalledProcessError(17, ["pkexec", "cp", "secret-argument"],
                                             output="secret-output", stderr="secret-stderr")
        with patch.object(adapter, "deploy", side_effect=error), self.assertLogs("desktop-installer") as logs:
            result = adapter.run()
        self.assertIn("cp failed (exit code 17)", result[1])
        self.assertNotIn("secret", str(result) + str(logs.output))

    def test_os_failure_does_not_expose_filename(self):
        calamares.globalstorage = self.storage()
        calamares.job.configuration = {"stage": "install"}
        with patch.object(adapter, "deploy", side_effect=OSError(2, "secret", "secret-path")), self.assertLogs("desktop-installer") as logs:
            result = adapter.run()
        self.assertIn("errno 2", result[1])
        self.assertNotIn("secret", str(result) + str(logs.output))


if __name__ == "__main__":
    unittest.main()
