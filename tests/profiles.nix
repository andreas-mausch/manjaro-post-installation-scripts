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
    assert !target.programs.kde-pim.enable;
    assert !live.programs.kde-pim.enable;
    assert
      !lib.elem build.target.pkgs.kdePackages.plasma-workspace-wallpapers target.environment.systemPackages;
    assert
      !lib.elem build.installer.pkgs.kdePackages.plasma-workspace-wallpapers live.environment.systemPackages;
    assert !desktop || lib.elem build.target.pkgs.kdePackages.breeze target.environment.systemPackages;
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
    assert live.hardware.bluetooth.enable;
    assert live.networking.nftables.enable;
    assert
      live.services.openssh.enable == lib.any (
        file:
        lib.any (line: builtins.match "[[:space:]]*(#.*)?" line == null) (
          lib.splitString "\n" (builtins.readFile file)
        )
      ) live.users.users.nixos.openssh.authorizedKeys.keyFiles;
    assert !target.services.openssh.enable;
    assert live.services.openssh.settings.PasswordAuthentication == false;
    assert live.services.openssh.settings.KbdInteractiveAuthentication == false;
    assert live.services.openssh.settings.PermitRootLogin == "no";
    assert target.services.openssh.settings.PasswordAuthentication == false;
    assert target.services.openssh.settings.PermitRootLogin == "no";
    assert target.networking.nftables.enable;
    assert target.networking.firewall.enable;
    assert target.hardware.bluetooth.enable;
    assert live.hardware.cpu.amd.updateMicrocode;
    assert live.hardware.cpu.intel.updateMicrocode;
    assert target.hardware.cpu.amd.updateMicrocode;
    assert target.hardware.cpu.intel.updateMicrocode;
    assert live.services.pipewire.enable;
    assert target.services.pipewire.enable;
    assert lib.all (package: lib.elem package target.environment.systemPackages) (
      with build.target.pkgs;
      [
        inxi
        powertop
        powerstat
        lm_sensors
      ]
    );
    assert target.services.printing.enable == desktop;
    assert target.hardware.sane.enable == desktop;
    assert !build.installer.pkgs.espeak.mbrolaSupport;
    assert !build.target.pkgs.espeak.mbrolaSupport;
    assert live.services.speechd.enable;
    assert !desktop || target.services.speechd.enable;
    assert lib.elem
      (build.installer.pkgs.compressFirmwareZstd build.installer.pkgs.linux-firmware).outPath
      (map toString live.system.extraDependencies);
    assert
      !(lib.elem build.installer.pkgs.linux-firmware.outPath (
        map toString live.system.extraDependencies
      ));
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
