{
  lib,
  pkgs,
  modelFiles,
  offlineSystem,
  offlineTools,
  variantName,
  ...
}:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # The generic rescue ISO includes ZFS, which need not support this kernel.
  # These images only create btrfs and vfat filesystems.
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
  # No complete source or compiler closure for kernel/ROCm is included.
  system.extraDependencies = [ offlineSystem ] ++ offlineTools;
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  }
  // lib.optionalAttrs (modelFiles != null) (import ../modules/generative-ai/cache.nix);
  environment.systemPackages = [ pkgs.networkmanager ];
  image.baseName = lib.mkForce "nixos-${variantName}";
  # Avoid spending CPU compressing the roughly 115 GB of model files.
  isoImage.squashfsCompression = null;
}
