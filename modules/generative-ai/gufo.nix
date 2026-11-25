{
  pkgs,
  gufo,
  source,
}:
let
  releaseLock = builtins.fromJSON (
    builtins.readFile (
      if builtins.pathExists (source + "/flake.online.lock") then
        source + "/flake.online.lock"
      else
        source + "/flake.lock"
    )
  );
  revision =
    gufo.shortRev or (builtins.substring 0 7
      releaseLock.nodes.${releaseLock.nodes.${releaseLock.root}.inputs.gufo}.locked.rev
    );
in
# Local path inputs lack shortRev. Keep the release's build arguments so
# offline evaluation reuses the exact prebuilt package.
gufo.packages.${pkgs.stdenv.hostPlatform.system}.release.override { inherit revision; }
