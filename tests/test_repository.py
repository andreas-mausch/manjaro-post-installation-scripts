"""Exercise installer cloning from an explicitly supplied Git folder."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

sys.modules["libcalamares"] = SimpleNamespace(utils=SimpleNamespace(gettext_languages=lambda: ["en"]))
spec = importlib.util.spec_from_file_location("adapter", sys.argv[1])
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def host(*args, capture=False, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, text=True,
                          stdout=subprocess.PIPE if capture else None)


with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    source, destination = [root / name for name in ["source", "target"]]
    repo = source / "repository"
    source.mkdir()
    destination.mkdir()
    host("git", "init", "--initial-branch=nixos", repo)
    (repo / "module.nix").write_text("{ ... }: {}\n")
    host("git", "-C", repo, "add", "module.nix")
    host("git", "-C", repo, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "commit", "-m", "Fixture")
    revision = host("git", "-C", repo, "rev-parse", "HEAD", capture=True).stdout.strip()
    (destination / "repository").symlink_to(repo)
    (destination / "configuration.nix").write_text("host data")
    remote = "https://example.invalid/setup.git"
    with patch.object(adapter, "host", host):
        adapter.provision_repository(source, destination, remote)
    checkout = destination / "my-os-setup"
    assert host("git", "-C", checkout, "rev-parse", "HEAD", capture=True).stdout.strip() == revision
    assert host("git", "-C", checkout, "symbolic-ref", "--short", "HEAD", capture=True).stdout.strip() == "nixos"
    assert host("git", "-C", checkout, "rev-parse", "--abbrev-ref", "@{upstream}", capture=True).stdout.strip() == "origin/nixos"
    assert host("git", "-C", checkout, "remote", "get-url", "origin", capture=True).stdout.strip() == remote
    assert (destination / "configuration.nix").read_text() == "host data"
    assert not (destination / "repository").exists()
    missing = root / "missing"
    missing.mkdir()
    with patch.object(adapter, "host", host):
        try:
            adapter.provision_repository(missing, destination, remote)
        except ValueError:
            pass
        else:
            raise AssertionError("Missing Git folder accepted")
print("Git folder: exact revision, named branch, upstream, remote and host preservation OK")
