{ pkgs, ... }:
let
  dhcpSources = pkgs.writeShellApplication {
    name = "timesyncd-dhcp-sources";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.gnused
      pkgs.networkmanager
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      exec ${pkgs.dash}/bin/dash ${./time-sync/dhcp-sources.sh} "$@"
    '';
  };
in
{
  networking.timeServers = [ ];
  services.timesyncd = {
    enable = true;
    servers = [ ];
    fallbackServers = [ ];
  };
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = "${dhcpSources}/bin/timesyncd-dhcp-sources";
    }
  ];
  # Also populate sources when switching configuration on an existing connection.
  systemd.services.timesyncd-dhcp-sources = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "NetworkManager.service"
      "systemd-timesyncd.service"
    ];
    wants = [ "systemd-timesyncd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${dhcpSources}/bin/timesyncd-dhcp-sources --refresh";
    };
  };
}
