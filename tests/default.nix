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
  reusable-module-tests = import ./reusable-modules.nix {
    inherit
      pkgs
      nixpkgs
      gufoPackage
      profiles
      ;
  };
}
