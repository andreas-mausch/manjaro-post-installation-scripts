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
    for filename in ["flake.lock", "flake.online.lock"]:
        lock = json.loads((Path(source) / filename).read_text())
        inputs = lock["nodes"][lock["root"]]["inputs"]
        assert ("gufo" in inputs) == ai, (name, filename)
        if not ai:
            assert set(lock["nodes"]) == {lock["root"], inputs["nixpkgs"]}, (name, filename)
    flake = (Path(source) / "flake.nix").read_text()
    assert "nixConfig" not in flake, name
    assert "extra-substituters" not in flake, name
    assert "extra-trusted-public-keys" not in flake, name
    if ai:
        assert "outputs = inputs@{ self, gufo, nixpkgs }: (import ./setup-flake.nix).outputs inputs;" in flake, name
        assert (Path(source) / "setup-flake.nix").is_file(), name
    else:
        assert "gufo" not in flake, name
        assert f"nixosConfigurations = {{ {name} = target; }}" in flake, name
        assert f"./profiles/{name}.nix" in flake, name
        assert "./modules/target-configuration.nix" in flake, name
        assert '"${target.config.networking.hostName}" = target;' in flake, name
