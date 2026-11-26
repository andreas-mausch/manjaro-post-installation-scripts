{
  pkgs,
  nixpkgs,
  gufoPackage,
  modules,
}:
let
  valid =
    pkgs.lib.all
      (
        name:
        let
          target = nixpkgs.lib.nixosSystem {
            system = pkgs.stdenv.hostPlatform.system;
            specialArgs = { inherit gufoPackage; };
            modules = [
              modules.${name}
              {
                fileSystems."/" = {
                  device = "/dev/disk/by-uuid/consumer-root";
                  fsType = "ext4";
                };
                fileSystems."/boot" = {
                  device = "/dev/disk/by-uuid/consumer-efi";
                  fsType = "vfat";
                };
                users.users.consumer.isNormalUser = true;
              }
            ];
          };
          config = target.config;
        in
        assert config.fileSystems."/".device == "/dev/disk/by-uuid/consumer-root";
        assert config.fileSystems."/".fsType == "ext4";
        assert config.fileSystems."/boot".device == "/dev/disk/by-uuid/consumer-efi";
        assert config.users.users.consumer.isNormalUser;
        assert !(config.users.users ? desktopuser);
        true
      )
      [
        "base"
        "desktop"
        "gaming"
        "generative-ai"
      ];
in
assert valid;
pkgs.runCommand "reusable-module-tests" { } ''
  touch "$out"
''
