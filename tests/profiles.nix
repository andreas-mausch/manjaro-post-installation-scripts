{
  pkgs,
  builds,
  profiles,
}:
let
  lib = pkgs.lib;
  cache = import ../modules/generative-ai/cache.nix;
  modelDirectoryOptions = [
    [ "directory" ]
    [
      "text-generation"
      "directory"
    ]
    [
      "text-generation"
      "qwen38FlashNext"
      "directory"
    ]
  ];
  modelPathsValid = lib.all (
    option:
    lib.all
      (
        path:
        let
          modified = builds.ai.target.extendModules {
            modules = [
              (lib.setAttrByPath (
                [
                  "generative-ai"
                  "models"
                ]
                ++ option
              ) path)
            ];
          };
          result = builtins.tryEval (
            builtins.deepSeq (lib.getAttrFromPath option modified.config.generative-ai.models) true
          );
        in
        !result.success
      )
      [
        "/"
        "relative/models"
        "/srv/models/../etc"
        "/srv/models/."
        "/srv//models"
        "/srv/models/"
      ]
  ) modelDirectoryOptions;
  valid = lib.all (
    name:
    let
      build = builds.${name};
      target = build.target.config;
      live = build.installer.config;
      wrappedCalamares = build.installer.pkgs.calamares-nixos;
      ai = profiles.${name}.ai;
      customAI = build.target.extendModules {
        modules = [ { generative-ai.models.directory = "/srv/ai/models"; } ];
      };
      allowsUnfree = target.nixpkgs.config.allowUnfreePredicate or (_: false);
      desktop = name != "base";
      gaming = builtins.elem name [
        "gaming"
        "full"
      ];
    in
    assert target.services.desktopManager.plasma6.enable == desktop;
    assert target.services.displayManager.sddm.enable == desktop;
    assert target.programs.firefox.enable == desktop;
    assert target.programs.steam.enable == gaming;
    assert !(target.nixpkgs.config.allowUnfree or false);
    assert !(live.nixpkgs.config.allowUnfree or false);
    assert allowsUnfree { pname = "steam"; } == gaming;
    assert allowsUnfree { pname = "steam-unwrapped"; } == gaming;
    assert !(allowsUnfree { pname = "unrelated-proprietary-app"; });
    assert (target.systemd.services ? gufo) == ai;
    assert (target.users.users ? gufo) == ai;
    assert
      (target.nix.settings.extra-substituters or [ ]) == (if ai then cache.extra-substituters else [ ]);
    assert
      (live.nix.settings.extra-substituters or [ ]) == (if ai then cache.extra-substituters else [ ]);
    assert !ai || target.nix.settings.extra-trusted-public-keys == cache.extra-trusted-public-keys;
    assert !ai || live.nix.settings.extra-trusted-public-keys == cache.extra-trusted-public-keys;
    assert !ai || target.generative-ai.models.directory == "/var/lib/generative-ai/models";
    assert !ai || customAI.config.systemd.services.gufo.environment.GUFO_MODELS_DIR == "/srv/ai/models";
    assert
      !ai
      || lib.hasInfix "--model /srv/ai/models/text-generation/Qwen3.8-Flash-Next/UD-Q4_K_XL/" customAI.config.systemd.services.gufo.serviceConfig.ExecStart;
    assert
      !ai
      || lib.hasInfix "--mtp-model /srv/ai/models/text-generation/Qwen3.8-Flash-Next/MTP/" customAI.config.systemd.services.gufo.serviceConfig.ExecStart;
    assert !(target.nix.settings ? always-allow-substitutes);
    assert live.services.desktopManager.plasma6.enable;
    assert live.console.keyMap == "us";
    assert live.time.timeZone == "UTC";
    assert lib.all
      (
        system:
        system.networking.networkmanager.enable
        && system.networking.networkmanager.wifi.backend == "iwd"
        && system.networking.wireless.iwd.enable
        && !system.networking.wireless.enable
        && !system.networking.wireless.iwd.settings.General.EnableNetworkConfiguration
        && !(system.systemd.services ? wpa_supplicant)
        && !(lib.any (package: lib.getName package == "wpa_supplicant") system.environment.systemPackages)
      )
      [
        live
        target
      ];
    assert live.services.spice-vdagentd.enable;
    assert live.environment.etc ? "xdg/autostart/spice-vdagent.desktop";
    assert live.environment.etc."xdg/autostart/spice-vdagent.desktop".source != null;
    assert (live.environment.etc ? "desktop-installer/models") == ai;
    assert live.image.baseName == "nixos-${name}";
    assert live.image.fileName == "nixos-${name}.iso";
    assert wrappedCalamares.unwrapped.drvPath == pkgs.calamares.drvPath;
    true
  ) (builtins.attrNames profiles);
in
assert valid;
assert modelPathsValid;
assert !((import ../flake.nix) ? nixConfig);
pkgs.runCommand "installer-profile-tests" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  python3 ${./test_profiles.py} ${
    lib.concatMapStringsSep " " (
      name:
      "${name} ${builds.${name}.calamaresExtensions} ${builds.${name}.offlineSource} ${
        builds.${name}.installer.pkgs.calamares-nixos
      }"
    ) (builtins.attrNames profiles)
  }
  touch "$out"
''
