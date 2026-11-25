{
  lib,
  pkgs,
  ...
}:
let
  identityFile = ../installation.json;
  identity =
    if builtins.pathExists identityFile then
      builtins.fromJSON (builtins.readFile identityFile)
    else
      { username = "desktopuser"; };
  hardwareFile = ../hardware-configuration.nix;
in
{
  imports = lib.optional (builtins.pathExists hardwareFile) hardwareFile;
  # Only for evaluation before Calamares generates the real UUID-based layout.
  fileSystems = lib.mkIf (!(builtins.pathExists hardwareFile)) {
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

  networking.hostName = identity.hostname or "nixos-desktop";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  time.timeZone = identity.timezone or "Europe/Berlin";
  i18n.defaultLocale = identity.locale or "de_DE.UTF-8";
  # Keep the locale archive invariant when Calamares selects a different locale.
  i18n.supportedLocales = [ "all" ];
  console.keyMap = identity.consoleKeyMap or "de";
  services.xserver.xkb = {
    layout = identity.keyboardLayout or "de";
    variant = identity.keyboardVariant or "";
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
  users.users.${identity.username} = {
    isNormalUser = true;
    description = identity.fullname or "";
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
  system.stateVersion = "26.05";
}
