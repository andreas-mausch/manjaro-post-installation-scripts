{
  pkgs,
  self,
  nixpkgs,
  gufo,
  system,
  name,
  profileSpec,
  ssh-keys,
  mkTarget,
}:
let
  lib = nixpkgs.lib;
  archive = import ./offline-source.nix {
    inherit
      pkgs
      self
      nixpkgs
      system
      name
      ;
    sshKeysFile = ssh-keys + "/authorized_keys";
    rootInputs = {
      inherit nixpkgs ssh-keys;
    }
    // lib.optionalAttrs profileSpec.ai { inherit gufo; };
    targetProfile = profileSpec.profile;
    reuseSetupOutputs = profileSpec.ai;
  };
  inherit (archive) inputSources offlineSource;
  target = mkTarget inputSources;
  offline = import ./offline.nix {
    inherit pkgs lib target;
    sshKeysFile = ssh-keys + "/authorized_keys";
  };
  inherit (offline) offlineSeed offlineSystem;
  offlineTools = offline.offlineTools ++ calamares.offlinePackages;
  modelFiles = import ../modules/generative-ai/model-files.nix {
    inherit pkgs gufo;
    models = offlineSeed.config.generative-ai.models;
  };
  calamares = import ../modules/installer/calamares.nix {
    inherit pkgs lib offlineSource;
    variantName = name;
    withModels = profileSpec.ai;
    modelFiles = if profileSpec.ai then modelFiles else null;
    modelsDirectory =
      if profileSpec.ai then offlineSeed.config.generative-ai.models.directory else null;
  };
  inherit (calamares) calamaresExtensions welcomeModule;
  installer = lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit calamaresExtensions offlineSystem offlineTools;
      sshKeysFile = ssh-keys + "/authorized_keys";
      modelFiles = if profileSpec.ai then modelFiles else null;
      variantName = name;
    };
    modules = [
      (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix")
      ./live.nix
      ../modules/installer
    ];
  };
in
{
  inherit
    target
    installer
    calamaresExtensions
    welcomeModule
    modelFiles
    offlineSource
    offlineSystem
    ;
}
