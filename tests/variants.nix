{
  pkgs,
  builds,
  variants,
}:
let
  lib = pkgs.lib;
  valid = lib.all (
    name:
    let
      build = builds.${name};
      target = build.target.config;
      live = build.installer.config;
      wrappedCalamares = build.installer.pkgs.calamares-nixos;
      ai = variants.${name}.ai;
      allowsUnfree = target.nixpkgs.config.allowUnfreePredicate or (_: false);
      desktop = name != "base";
      gaming = builtins.elem name [
        "gaming"
        "full"
      ];
    in
    assert target.services.desktopManager.plasma6.enable == desktop;
    assert target.services.displayManager.sddm.enable == desktop;
    assert target.programs.firefox.enable == desktop;
    assert target.programs.steam.enable == gaming;
    assert !(target.nixpkgs.config.allowUnfree or false);
    assert !(live.nixpkgs.config.allowUnfree or false);
    assert allowsUnfree { pname = "steam"; } == gaming;
    assert allowsUnfree { pname = "steam-unwrapped"; } == gaming;
    assert !(allowsUnfree { pname = "unrelated-proprietary-app"; });
    assert (target.systemd.services ? gufo) == ai;
    assert (target.users.users ? gufo) == ai;
    assert !(target.nix.settings ? always-allow-substitutes);
    assert live.services.desktopManager.plasma6.enable;
    assert (live.environment.etc ? "desktop-installer/models") == ai;
    assert live.image.fileName == "nixos-${name}-installer.iso";
    assert wrappedCalamares.unwrapped.drvPath == pkgs.calamares.drvPath;
    true
  ) (builtins.attrNames variants);
in
assert valid;
pkgs.runCommand "installer-variant-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 ${./test_variants.py} ${
    lib.concatMapStringsSep " " (
      name:
      "${name} ${builds.${name}.calamaresExtensions} ${builds.${name}.offlineSource} ${
        builds.${name}.installer.pkgs.calamares-nixos
      }"
    ) (builtins.attrNames variants)
  }
  touch "$out"
''
