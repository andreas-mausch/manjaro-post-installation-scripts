{
  pkgs,
  self,
  nixpkgs,
  gufo,
  system,
  name,
  variant,
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
    rootInputs = {
      inherit nixpkgs;
    }
    // lib.optionalAttrs variant.ai { inherit gufo; };
    targetProfile = variant.profile;
    reuseSetupOutputs = variant.ai;
  };
  inherit (archive) inputSources offlineSource;
  target = mkTarget inputSources;
  offline = import ./offline.nix { inherit pkgs lib target; };
  inherit (offline) offlineSeed offlineSystem;
  offlineTools = offline.offlineTools ++ calamares.offlinePackages;
  modelFiles = import ../modules/generative-ai/model-files.nix {
    inherit pkgs gufo;
    models = offlineSeed.config.generative-ai.models;
  };
  calamares = import ../modules/installer/calamares.nix {
    inherit pkgs lib offlineSource;
    variantName = name;
    withModels = variant.ai;
    modelFiles = if variant.ai then modelFiles else null;
    modelsDirectory = if variant.ai then offlineSeed.config.generative-ai.models.directory else null;
  };
  inherit (calamares) calamaresExtensions welcomeModule;
  installer = lib.nixosSystem {
    inherit system;
    specialArgs = {
      inherit calamaresExtensions offlineSystem offlineTools;
      modelFiles = if variant.ai then modelFiles else null;
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
