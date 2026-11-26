{ lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Generated hardware configuration selects drivers and CPU microcode.
  hardware.enableRedistributableFirmware = true;

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  time.timeZone = lib.mkDefault "Europe/Berlin";
  i18n.defaultLocale = lib.mkDefault "de_DE.UTF-8";
  # Keep the locale archive invariant across installation language choices.
  i18n.supportedLocales = [ "all" ];
  console.keyMap = lib.mkDefault "de";
  services.xserver.xkb = {
    layout = lib.mkDefault "de";
    variant = lib.mkDefault "";
  };

  services.fstrim.enable = true;
  programs.git.enable = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Persistent hashes live on the target, never in a flake or the Nix store.
  users.mutableUsers = false;
  users.users.root.hashedPassword = "!";
  environment.systemPackages = [ pkgs.curl ];
  systemd.tmpfiles.rules = [ "d /var/lib/nixos-secrets 0700 root root -" ];
  system.stateVersion = lib.mkDefault "26.05";
}
