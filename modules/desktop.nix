{
  lib,
  pkgs,
  gufoPackage,
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
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  hardware.bluetooth.enable = true;
  services.fstrim.enable = true;

  nixpkgs.config.allowUnfree = true;
  programs.steam.enable = true;
  programs.firefox.enable = true;
  programs.git.enable = true;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    extra-substituters = [ "https://gufo.cachix.org" ];
    extra-trusted-public-keys = [
      "gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE="
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
  users.groups.gufo = { };
  users.users.gufo = {
    isSystemUser = true;
    group = "gufo";
    extraGroups = [
      "video"
      "render"
    ];
    home = "/var/lib/gufo";
  };
  security.pam.loginLimits = [
    {
      domain = "@render";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];
  environment.systemPackages = [
    gufoPackage
    pkgs.curl
  ];
  environment.variables.GUFO_MODELS_DIR = "/var/lib/gufo/models";
  systemd.tmpfiles.rules = [
    "d /var/lib/gufo 0755 gufo gufo -"
    "d /var/lib/gufo/models 0755 gufo gufo -"
    # Also repair ownership after recovering an interrupted model copy.
    "Z /var/lib/gufo/models - gufo gufo -"
    "d /var/lib/nixos-secrets 0700 root root -"
  ];
  systemd.services.gufo = {
    description = "Gufo Qwen3.8 Flash-Next (manual start; stop before gaming)";
    # Intentionally no wantedBy: installed, but not started at boot.
    environment.GUFO_MODELS_DIR = "/var/lib/gufo/models";
    serviceConfig = {
      User = "gufo";
      Group = "gufo";
      SupplementaryGroups = [
        "video"
        "render"
      ];
      StateDirectory = "gufo";
      LimitMEMLOCK = "infinity";
      TimeoutStopSec = 60;
      ExecStart = lib.concatStringsSep " " [
        "${gufoPackage}/bin/gufo serve --host 127.0.0.1 --port 8080 llm"
        "--model flash-next-q4 --served-model-name flash-next"
        "--speculative mtp"
        "--mtp-model /var/lib/gufo/models/flash-next-q4/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
        "--sessions 1 --context 32768"
      ];
    };
  };
  system.stateVersion = "26.05";
}
