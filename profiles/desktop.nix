{ pkgs, ... }:
{
  imports = [
    ./base.nix
    (import ../modules/spice.nix { inherit pkgs; }).nixosModule
  ];
  hardware.graphics.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  # Omit KDE's mail/calendar/contact suite and its Akonadi/MariaDB backend.
  programs.kde-pim.enable = false;
  environment.plasma6.excludePackages = [ pkgs.kdePackages.plasma-workspace-wallpapers ];
  services.printing.enable = true;
  hardware.sane.enable = true;
  programs.firefox.enable = true;
}
