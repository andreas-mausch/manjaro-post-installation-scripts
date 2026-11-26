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
  services.printing.enable = true;
  hardware.sane.enable = true;
  programs.firefox.enable = true;
}
