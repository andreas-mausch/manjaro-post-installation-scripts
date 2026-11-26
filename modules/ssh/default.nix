{ lib, ... }:
{
  # Base leaves SSH disabled; the installer/local configuration opts in.
  services.openssh = {
    enable = lib.mkDefault false;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
