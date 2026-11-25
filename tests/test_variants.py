"""Check built installer settings and archived sources without installing NixOS."""
import json
from pathlib import Path
import sys

for index in range(1, len(sys.argv), 3):
    name, extensions, source = sys.argv[index:index + 3]
    ai = name in {"ai", "full"}
    configs = Path(extensions) / "etc/calamares"
    settings = json.loads((configs / "settings.conf").read_text())
    modules = configs / "modules"
    shown = settings["sequence"][0]["show"]
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
    if not ai:
        flake = (Path(source) / "flake.nix").read_text()
        assert "gufo" not in flake, name
        assert f"nixosConfigurations.{name}" in flake, name
