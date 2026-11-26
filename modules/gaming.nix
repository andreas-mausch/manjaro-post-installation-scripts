{ lib, ... }:
{
  hardware.graphics.enable32Bit = true;
  services.pipewire.alsa.support32Bit = true;
  programs.steam.enable = true;
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-unwrapped"
    ];
}
