{ lib, gufoPackage, ... }:
{
  imports = [ ../base.nix ];
  hardware.graphics.enable = true;
  nix.settings = {
    extra-substituters = [ "https://gufo.cachix.org" ];
    extra-trusted-public-keys = [
      "gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE="
    ];
  };
  users.groups.gufo = { };
  users.users.gufo = {
    isSystemUser = true;
    group = "gufo";
    extraGroups = [
      "video"
      "render"
    ];
    home = "/var/lib/gufo";
  };
  security.pam.loginLimits = [
    {
      domain = "@render";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];
  environment.systemPackages = [ gufoPackage ];
  environment.variables.GUFO_MODELS_DIR = "/var/lib/gufo/models";
  systemd.tmpfiles.rules = [
    "d /var/lib/gufo 0755 gufo gufo -"
    "d /var/lib/gufo/models 0755 gufo gufo -"
    "Z /var/lib/gufo/models - gufo gufo -"
  ];
  systemd.services.gufo = {
    description = "Gufo Qwen3.8 Flash-Next (manual start; stop before gaming)";
    # No wantedBy: installed, but not started at boot.
    environment.GUFO_MODELS_DIR = "/var/lib/gufo/models";
    serviceConfig = {
      User = "gufo";
      Group = "gufo";
      SupplementaryGroups = [
        "video"
        "render"
      ];
      StateDirectory = "gufo";
      LimitMEMLOCK = "infinity";
      TimeoutStopSec = 60;
      ExecStart = lib.concatStringsSep " " [
        "${gufoPackage}/bin/gufo serve --host 127.0.0.1 --port 8080 llm"
        "--model flash-next-q4 --served-model-name flash-next"
        "--speculative mtp"
        "--mtp-model /var/lib/gufo/models/flash-next-q4/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf"
        "--sessions 1 --context 32768"
      ];
    };
  };
}
