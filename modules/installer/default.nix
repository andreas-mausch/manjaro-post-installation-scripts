{
  pkgs,
  calamaresExtensions,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      calamares-nixos-extensions = calamaresExtensions;
      calamares-nixos = final.callPackage ./calamares-package.nix {
        calamares = prev.calamares;
        inherit calamaresExtensions;
      };
    })
  ];
  environment.systemPackages = [
    pkgs.mkpasswd
    pkgs.nixos-install-tools
    pkgs.coreutils
    pkgs.cryptsetup
  ];
}
