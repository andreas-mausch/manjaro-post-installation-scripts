{ lib, ... }:
let
  localConfiguration = ../configuration.nix;
  hardwareFile = ../hardware-configuration.nix;
  installed = builtins.pathExists localConfiguration;
in
{
  # Repository target composition only; never imported by reusable modules.
  imports =
    lib.optional installed localConfiguration
    ++ lib.optional (!installed && builtins.pathExists hardwareFile) hardwareFile;

  # Reference layout for evaluation and offline package preparation. Calamares
  # generates the installed PC's configuration before evaluating its target.
  fileSystems = lib.mkIf (!installed && !(builtins.pathExists hardwareFile)) {
    "/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
    };
  };
  users.users.desktopuser = lib.mkIf (!installed) {
    isNormalUser = true;
    description = "";
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
    ];
    hashedPasswordFile = "/var/lib/nixos-secrets/user-password.hash";
  };
}
