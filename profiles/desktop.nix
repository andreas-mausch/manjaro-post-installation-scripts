{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./base.nix
    (import ../modules/spice.nix { inherit pkgs; }).nixosModule
  ];
  hardware.graphics.enable = true;
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
  # Prefer mutable KDE timezone settings over Base's declarative default.
  time.timeZone = lib.mkOverride 900 null;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  # Release Plymouth before SDDM starts, but keep its final frame on screen.
  systemd.services.plymouth-quit = lib.mkIf config.boot.plymouth.enable {
    serviceConfig.ExecStart = [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  };
  services.desktopManager.plasma6.enable = true;
  # Omit KDE's mail/calendar/contact suite and its Akonadi/MariaDB backend.
  programs.kde-pim.enable = false;
  environment.plasma6.excludePackages = [ pkgs.kdePackages.plasma-workspace-wallpapers ];
  services.printing.enable = true;
  hardware.sane.enable = true;
  programs.firefox.enable = true;
}
