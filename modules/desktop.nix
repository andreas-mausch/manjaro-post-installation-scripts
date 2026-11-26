{ pkgs, ... }:
{
  imports = [
    ./base.nix
    (import ./spice.nix { inherit pkgs; }).nixosModule
  ];
  hardware.graphics.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
  hardware.bluetooth.enable = true;
  programs.firefox.enable = true;
}
