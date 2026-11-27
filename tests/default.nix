{
  pkgs,
  nixpkgs,
  gufoPackage,
  builds,
  profiles,
}:
{
  installer-tests =
    pkgs.runCommand "desktop-installer-tests"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.git
        ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python3 ${./test_calamares.py} ${../modules/installer/calamares/main.py}
        python3 ${./test_repository.py} ${../modules/installer/calamares/main.py}
        touch "$out"
      '';
  profile-tests = import ./profiles.nix { inherit pkgs builds profiles; };
  uki-hook-tests = pkgs.runCommand "uki-hook-tests" { } ''
    ${pkgs.lib.concatMapStringsSep "\n" (name: ''
      test -x ${builds.${name}.target.config.system.build.installBootLoader}
    '') (builtins.attrNames profiles)}
    touch "$out"
  '';
  uki-entry-tests =
    pkgs.runCommand "uki-entry-tests"
      {
        nativeBuildInputs = [ (pkgs.python3.withPackages (packages: [ packages.virt-firmware ])) ];
      }
      ''
        export PYTHONDONTWRITEBYTECODE=1
        python3 ${./test_uki_entries.py} ${../modules/uki/entries.py}
        touch "$out"
      '';
  reusable-module-tests = import ./reusable-modules.nix {
    inherit
      pkgs
      nixpkgs
      gufoPackage
      profiles
      ;
  };
}
