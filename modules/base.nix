{
  lib,
  pkgs,
  ...
}:
let
  # Installed systems own local settings in configuration.nix.
  localConfiguration = builtins.pathExists ../configuration.nix;
  hardwareFile = ../hardware-configuration.nix;
in
{
  imports = lib.optional (!localConfiguration && builtins.pathExists hardwareFile) hardwareFile;
  # Only for evaluation before Calamares generates the real UUID-based layout.
  fileSystems = lib.mkIf (!localConfiguration && !(builtins.pathExists hardwareFile)) {
    "/" = {
      device = "/dev/mapper/cryptroot";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Device drivers and CPU microcode are selected by the generated hardware
  # configuration. Do not impose GPU memory limits for a particular machine.
  hardware.enableRedistributableFirmware = true;

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "de_DE.UTF-8";
  # Keep the locale archive invariant when Calamares selects a different locale.
  i18n.supportedLocales = [ "all" ];
  console.keyMap = lib.mkDefault "de";
  services.xserver.xkb = {
    layout = lib.mkDefault "de";
    variant = lib.mkDefault "";
  };

  services.fstrim.enable = true;

  programs.git.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
  # Password hashes are only stored on the encrypted target, never in a flake.
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  users.users.desktopuser = lib.mkIf (!localConfiguration) {
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
  environment.systemPackages = [ pkgs.curl ];
  systemd.tmpfiles.rules = [
    "d /var/lib/nixos-secrets 0700 root root -"
  ];
  system.stateVersion = lib.mkDefault "26.05";
}
