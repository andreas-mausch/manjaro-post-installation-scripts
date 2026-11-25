{
  lib,
  pkgs,
  installer,
  ...
}:
{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # The generic rescue ISO includes ZFS, which need not support this kernel.
  # This installer only creates ext4 and vfat filesystems.
  boot.supportedFilesystems.zfs = lib.mkForce false;
  hardware.enableRedistributableFirmware = true;
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  services.openssh.enable = lib.mkForce false;
  services.getty.autologinUser = lib.mkForce "root";
  console.keyMap = "de";
  time.timeZone = "Europe/Berlin";
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
    installer
    pkgs.networkmanager
  ];
  programs.bash.interactiveShellInit = ''
    if [[ $(tty) == /dev/tty1 && -z ''${M5_INSTALLER_STARTED:-} ]]; then
      export M5_INSTALLER_STARTED=1
      install-m5
      echo 'Installer beendet. Erneut starten: install-m5; Netzwerk: nmtui'
    fi
  '';
  image.fileName = lib.mkForce "bosgame-m5-installer.iso";
}
