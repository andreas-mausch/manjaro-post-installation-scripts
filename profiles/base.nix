{ lib, pkgs, ... }:
{
  imports = [
    ../modules/networking.nix
    ../modules/speech.nix
    ../modules/ssh
    ../modules/uki.nix
  ];
  hardware.bluetooth.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.cpu.intel.updateMicrocode = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.plymouth = {
    enable = lib.mkDefault true;
    theme = lib.mkDefault "abstract_ring";
    # Include only the selected theme, not the full animation collection.
    themePackages = [
      (import ../modules/plymouth-theme.nix { inherit pkgs; })
    ];
  };
  # Escape exposes boot messages; Plymouth retains its native text fallback.
  boot.kernelParams = [
    "quiet"
    # QEMU's serial console must not force Plymouth's text-only details view.
    "plymouth.ignore-serial-consoles"
  ];
  # Generated hardware configuration selects drivers and CPU microcode.
  hardware.enableRedistributableFirmware = true;

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
  environment.systemPackages = with pkgs; [
    curl
    inxi
    powertop
    powerstat
    lm_sensors
  ];
  systemd.tmpfiles.rules = [ "d /var/lib/nixos-secrets 0700 root root -" ];
  system.stateVersion = lib.mkDefault "26.05";
}
