"""Boot-entry lifecycle tests using virt-firmware's EFI model, no NVRAM writes."""
import importlib.util
import json
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

from virt.firmware.bootcfg.bootcfg import EfiBootConfig
from virt.firmware.efi import bootentry, devpath, ucs16

spec = importlib.util.spec_from_file_location("roles", sys.argv.pop(1))
roles = importlib.util.module_from_spec(spec)
spec.loader.exec_module(roles)


def devicepath(file, guid="12345678-1234-1234-1234-123456789abc"):
    partition, filename = devpath.DevicePathElem(), devpath.DevicePathElem()
    partition.set_gpt(1, 2048, 100000, guid)
    filename.set_filepath(file)
    path = devpath.DevicePath()
    path.extend([partition, filename])
    return path


class RoleTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.images = {}
        for name in ["a", "b", "c"]:
            image = self.directory / (name + ".efi")
            image.write_bytes(b"UKI fixture")
            self.images[name] = image
        self.cfg = EfiBootConfig()
        for method in ["linux_write_entry", "linux_remove_entry", "linux_update_order", "linux_update_next"]:
            setattr(self.cfg, method, Mock())
        self.foreign = self.cfg.add_entry(bootentry.BootEntry(
            title=ucs16.from_string("Linux Boot Manager"),
            devicepath=devicepath("\\EFI\\systemd\\systemd-bootx64.efi")))
        self.cfg.set_boot_order(self.foreign, 0)

    def apply(self, desired):
        with patch.object(roles.linuxcfg, "LinuxEfiFile") as efifile:
            efifile.side_effect = lambda image: Mock(dev_path_file=lambda: devicepath("\\EFI\\my-os-setup\\" + Path(image).name))
            keep, partition = roles.register_roles(self.cfg, {role: self.images[target] for role, target in desired.items()})
        roles.remove_superseded(self.cfg, keep, partition)
        self.assertTrue(str(self.cfg.bentr[self.cfg.blist[0]].title).startswith("NixOS Current "))
        self.assertIn(self.foreign, self.cfg.blist)
        self.assertEqual(len(self.cfg.bentr), len(desired) + 1)
        return keep

    def test_install_update_repeat_and_rollback(self):
        state = roles.next_roles({}, "a", "a", "a")
        self.assertEqual(state, {"current": "a", "installation": "a"})
        self.apply(state)
        state = roles.next_roles(state, "b", "a", "a")
        self.assertEqual(state, {"current": "b", "backup": "a", "installation": "a"})
        keep = self.apply(state)
        self.assertEqual(keep, self.apply(roles.next_roles(state, "b", "a", "a")))
        state = roles.next_roles(state, "c", "a", "b")
        self.apply(state)
        state = roles.next_roles(state, "b", "a", "c")
        self.assertEqual(state, {"current": "b", "backup": "c", "installation": "a"})
        self.apply(state)
        self.assertTrue(all(len(str(self.cfg.bentr[nr].title).split()[-1]) == 5 for nr in self.cfg.bentr if nr != self.foreign))

    def test_existing_installation_does_not_invent_baseline(self):
        state = roles.next_roles({}, "b", None, "a")
        self.assertEqual(state, {"current": "b", "backup": "a"})
        self.apply(state)

    def test_identical_rebuild_does_not_write_nvram(self):
        desired = {"current": "b", "backup": "a", "installation": "a"}
        self.apply(desired)
        for method in ["linux_write_entry", "linux_remove_entry", "linux_update_order", "linux_update_next"]:
            getattr(self.cfg, method).reset_mock()
        self.apply(desired)
        for method in ["linux_write_entry", "linux_remove_entry", "linux_update_order", "linux_update_next"]:
            getattr(self.cfg, method).assert_not_called()

    def test_legacy_project_entries_removed_but_other_disk_preserved(self):
        legacy = self.cfg.add_entry(bootentry.BootEntry(
            title=ucs16.from_string("NixOS UKI Test"),
            devicepath=devicepath("\\EFI\\my-os-setup\\old.efi")))
        other = self.cfg.add_entry(bootentry.BootEntry(
            title=ucs16.from_string("Other disk"),
            devicepath=devicepath("\\EFI\\my-os-setup\\old.efi", "aaaaaaaa-1234-1234-1234-123456789abc")))
        with patch.object(roles.linuxcfg, "LinuxEfiFile", return_value=Mock(dev_path_file=lambda: devicepath("\\EFI\\my-os-setup\\b.efi"))):
            keep, partition = roles.register_roles(self.cfg, {"current": self.images["b"]})
        roles.remove_superseded(self.cfg, keep, partition)
        self.assertNotIn(legacy, self.cfg.bentr)
        self.assertIn(other, self.cfg.bentr)
        self.assertIn(self.foreign, self.cfg.bentr)

    def test_registration_failure_does_not_remove_old_entries(self):
        self.cfg.linux_write_entry.side_effect = OSError("NVRAM full")
        with patch.object(roles.linuxcfg, "LinuxEfiFile", return_value=Mock(dev_path_file=lambda: devicepath("\\EFI\\my-os-setup\\b.efi"))):
            with self.assertRaises(OSError):
                roles.register_roles(self.cfg, {"current": self.images["b"]})
        self.cfg.linux_remove_entry.assert_not_called()
        self.assertIn(self.foreign, self.cfg.bentr)

    def test_new_installation_replaces_baseline(self):
        self.assertEqual(roles.next_roles({"current": "b", "installation": "a"}, "c", "c", "b")["installation"], "c")

    def test_failed_preparation_leaves_state_and_firmware_untouched(self):
        state = self.directory / "generations.json"
        original = {"current": str(self.directory), "backup": "old-system"}
        state.write_text(json.dumps(original))
        with patch.object(roles.linuxcfg, "LinuxEfiBootConfig", return_value=self.cfg), patch.object(roles.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "prepare-system-uki")):
            with self.assertRaises(subprocess.CalledProcessError):
                roles.manage(self.directory, self.directory, state, self.directory / "missing-root", self.directory)
        self.assertEqual(json.loads(state.read_text()), original)
        self.cfg.linux_write_entry.assert_not_called()
        self.cfg.linux_remove_entry.assert_not_called()


unittest.main()
