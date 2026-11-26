{
  lib,
  pkgs,
  modelFiles,
  offlineSystem,
  offlineTools,
  variantName,
  sshKeysFile,
  ...
}:
{
  imports = [
    ../modules/networking.nix
    ../modules/speech.nix
    ../modules/ssh
    (import ../modules/spice.nix { inherit pkgs; }).nixosModule
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # The generic rescue ISO includes ZFS, which need not support this kernel.
  # These images only create btrfs and vfat filesystems.
  boot.supportedFilesystems.zfs = lib.mkForce false;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.cpu.amd.updateMicrocode = true;
  hardware.cpu.intel.updateMicrocode = true;
  services.openssh.enable = true;
  users.users.nixos.openssh.authorizedKeys.keyFiles = [ sshKeysFile ];
  console.keyMap = "us";
  time.timeZone = "UTC";
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
