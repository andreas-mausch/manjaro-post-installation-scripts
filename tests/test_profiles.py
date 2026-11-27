"""Check built installer settings and archived sources without installing NixOS."""
import json
from pathlib import Path
import sys

for index in range(1, len(sys.argv), 4):
    name, extensions, source, wrapper = sys.argv[index:index + 4]
    wrapped = Path(wrapper)
    executable = str(wrapped / "bin/calamares")
    policy = (wrapped / "share/polkit-1/actions/io.calamares.calamares.policy").read_text()
    assert f'>{executable}</annotate>' in policy, name
    desktop = (wrapped / "share/applications/calamares.desktop").read_text()
    assert f'TryExec={executable}\n' in desktop, name
    assert f'pkexec {executable}' in desktop, name
    script = (wrapped / "bin/calamares").read_text()
    assert f'{extensions}/share' in script, name
    assert f'{extensions}/etc' in script, name
    assert '--xdg-config' in script, name
    assert '/dev/virtio-ports/com.redhat.spice.0' in script, name
    assert f'{extensions}/etc-spice' in script, name
    ai = name in {"ai", "full"}
    configs = Path(extensions) / "etc/calamares"
    settings = json.loads((configs / "settings.conf").read_text())
    modules = configs / "modules"
    shown = settings["sequence"][0]["show"]
    spice_settings = json.loads((Path(extensions) / "etc-spice/calamares/settings.conf").read_text())
    assert "packagechooser@spice" not in shown, name
    assert spice_settings["sequence"][0]["show"] == shown[:-1] + ["packagechooser@spice", "summary"], name
    assert spice_settings["sequence"][1:] == settings["sequence"][1:], name
    spice = json.loads((modules / "desktop-spice.conf").read_text())
    assert spice["mode"] == "optional" and spice["method"] == "legacy", name
    assert not spice.get("default"), name
    jobs = settings["sequence"][1]["exec"]
    assert ("packagechooser@models" in shown) == ai, name
    assert ("desktop@models" in jobs) == ai, name
    assert (modules / "desktop-models.conf").exists() == ai, name
    assert (modules / "desktop-copy-models.conf").exists() == ai, name
    install = json.loads((modules / "desktop-install.conf").read_text())
    validate = json.loads((modules / "desktop-validate.conf").read_text())
    assert install["target"] == name, name
    assert install["withModels"] == validate["withModels"] == ai, name
    assert not (Path(source) / "flake.online.lock").exists(), name
    for filename in ["flake.lock"]:
        lock = json.loads((Path(source) / filename).read_text())
        inputs = lock["nodes"][lock["root"]]["inputs"]
        if filename == "flake.lock":
            for node in lock["nodes"].values():
                if "locked" in node:
                    assert node["locked"]["type"] == "path", (name, node)
                    assert node["locked"]["narHash"].startswith("sha256-"), (name, node)
        assert ("gufo" in inputs) == ai, (name, filename)
        assert "my-os-setup" in inputs and "ssh-keys" not in inputs, (name, filename)
        assert lock["nodes"][inputs["my-os-setup"]]["flake"] is False
        if not ai:
            assert set(lock["nodes"]) == {lock["root"], inputs["nixpkgs"], inputs["my-os-setup"]}, (name, filename)
    flake = (Path(source) / "flake.nix").read_text()
    project = lock["nodes"][inputs["my-os-setup"]]["original"]
    assert install["repositoryRemote"] == f"https://github.com/{project['owner']}/{project['repo']}.git", name
    assert (Path(source) / "ssh-authorized-keys").is_file(), name
    ssh = json.loads((modules / "desktop-ssh.conf").read_text())
    assert "packagechooser@ssh" in shown, name
    assert ssh["mode"] == "optional", name
    assert [item["id"] for item in ssh["items"]] == ["", "ssh"], name
    key_file = (Path(source) / "ssh-authorized-keys").read_text()
    if not any(line.strip() and not line.lstrip().startswith("#") for line in key_file.splitlines()):
        assert "No public keys supplied" in ssh["items"][1]["description"], name
        assert "Keine öffentlichen Schlüssel" in ssh["items"][1]["description[de]"], name
    assert "nixConfig" not in flake, name
    assert "extra-substituters" not in flake, name
    assert "extra-trusted-public-keys" not in flake, name
    assert not (Path(source) / "setup-flake.nix").exists(), name
    assert "flake = false" in flake, name
    assert '(my-os-setup + "/profiles/' + name + '.nix")' in flake, name
    assert "./configuration.nix" in flake and "target-configuration.nix" not in flake, name
    if ai:
        assert 'github:gufo-org/gufo"' in flake, name
        assert "specialArgs.gufoPackage" in flake, name
    else:
        assert "gufo" not in flake, name
        assert f"nixosConfigurations = {{ {name} = target; default = target; }}" in flake, name
    assert '"${target.config.networking.hostName}" = target;' in flake, name
