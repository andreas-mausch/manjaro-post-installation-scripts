{
  pkgs,
  gufo,
  revision ? gufo.shortRev or "dirty",
}:
# Offline composition supplies the ISO revision for its retained path input.
gufo.packages.${pkgs.stdenv.hostPlatform.system}.release.override { inherit revision; }
