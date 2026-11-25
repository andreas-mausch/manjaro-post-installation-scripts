{
  lib,
  pkgs,
  calamaresExtensions,
  modelFiles,
  offlineSystem,
  offlineTools,
  variantName,
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
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # The generic rescue ISO includes ZFS, which need not support this kernel.
  # This installer only creates btrfs and vfat filesystems.
  boot.supportedFilesystems.zfs = lib.mkForce false;
  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
  console.keyMap = "de";
  time.timeZone = "Europe/Berlin";
  environment.etc = lib.optionalAttrs (modelFiles != null) {
    "desktop-installer/models".source = modelFiles;
  };
  # Reuse prebuilt packages and assembly tools through the live/local store.
  # No complete source or compiler closure for Kernel/ROCm is included.
  system.extraDependencies = [ offlineSystem ] ++ offlineTools;
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
  environment.systemPackages = [
    pkgs.networkmanager
    pkgs.mkpasswd
    pkgs.nixos-install-tools
    pkgs.coreutils
    pkgs.cryptsetup
  ];
  image.baseName = lib.mkForce "nixos-${variantName}";
  # Avoid spending CPU compressing the roughly 115 GB of model files.
  isoImage.squashfsCompression = null;
}
