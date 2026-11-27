{ ... }:
{
  imports = [ ./time-sync.nix ];
  networking.nftables.enable = true;
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };
  # NetworkManager handles IP/DNS; iwd only provides the Wi-Fi backend.
  networking.wireless.iwd.settings.General.EnableNetworkConfiguration = false;
  networking.wireless.enable = false;
}
