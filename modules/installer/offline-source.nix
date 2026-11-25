{
  pkgs,
  self,
  nixpkgs,
  system,
  name,
  rootInputs,
  targetModules,
  reuseSetupOutputs,
}:
let
  lib = nixpkgs.lib;
  fullLock = builtins.fromJSON (builtins.readFile (self + "/flake.lock"));
  reachable =
    nodeName:
    [ nodeName ]
    ++ lib.concatMap (edge: if builtins.isString edge then reachable edge else [ ]) (
      builtins.attrValues (fullLock.nodes.${nodeName}.inputs or { })
    );
  selectedNodes = lib.unique (
    lib.concatMap (inputName: reachable fullLock.nodes.${fullLock.root}.inputs.${inputName}) (
      builtins.attrNames rootInputs
    )
  );
  originalLock = fullLock // {
    nodes = (lib.filterAttrs (nodeName: _: builtins.elem nodeName selectedNodes) fullLock.nodes) // {
      ${fullLock.root} = {
        inputs = lib.filterAttrs (
          inputName: _: builtins.hasAttr inputName rootInputs
        ) fullLock.nodes.${fullLock.root}.inputs;
      };
    };
  };
  collectInputNodes =
    nodeName: input:
    [
      {
        name = nodeName;
        value = input.outPath;
      }
    ]
    ++ lib.concatMap (
      inputName:
      let
        edge = originalLock.nodes.${nodeName}.inputs.${inputName};
      in
      if builtins.isString edge then collectInputNodes edge input.inputs.${inputName} else [ ]
    ) (builtins.attrNames (originalLock.nodes.${nodeName}.inputs or { }));
  inputNodes = builtins.listToAttrs (
    lib.concatMap (
      inputName:
      collectInputNodes originalLock.nodes.${originalLock.root}.inputs.${inputName}
        rootInputs.${inputName}
    ) (builtins.attrNames rootInputs)
  );
  inputSources = lib.unique (builtins.attrValues inputNodes);
  localLock = originalLock // {
    nodes = builtins.mapAttrs (
      nodeName: node:
      if node ? locked then
        node
        // {
          locked = {
            type = "path";
            path = inputNodes.${nodeName};
            narHash = node.locked.narHash;
          };
        }
      else
        node
    ) originalLock.nodes;
  };
  localLockFile = pkgs.writeText "desktop-offline-flake.lock" (builtins.toJSON localLock);
  onlineLockFile = pkgs.writeText "${name}-online-flake.lock" (builtins.toJSON originalLock);
  # Reuse the original entry point even when rebuilding an installed archive.
  setupFlakePath =
    if builtins.pathExists (self + "/setup-flake.nix") then
      self + "/setup-flake.nix"
    else
      self + "/flake.nix";
  sourceInputs = lib.filterAttrs (
    inputName: _: builtins.hasAttr inputName rootInputs
  ) (import setupFlakePath).inputs;
  targetFlake = pkgs.writeText "${name}-flake.nix" ''
    {
      inputs = ${lib.generators.toPretty { } sourceInputs};
      outputs = { self, nixpkgs }: let
        target = nixpkgs.lib.nixosSystem {
          system = "${system}";
          modules = [ ${
            lib.concatMapStringsSep " " (module: "./modules/${builtins.baseNameOf module}") targetModules
          }
            { system.extraDependencies = [ nixpkgs.outPath ]; } ]
            ++ nixpkgs.lib.optional (builtins.pathExists ./configuration.nix) ./configuration.nix;
        };
      in {
        nixosConfigurations = { ${name} = target; }
        // nixpkgs.lib.optionalAttrs (builtins.pathExists ./configuration.nix) {
          "''${target.config.networking.hostName}" = target;
        };
      };
    }
  '';
  # Reuse revision-sensitive outputs without forwarding nixConfig.
  setupTargetFlake = pkgs.writeText "${name}-target-flake.nix" ''
    {
      inputs = ${lib.generators.toPretty { } sourceInputs};
      outputs = inputs@{ self, ${lib.concatStringsSep ", " (builtins.attrNames rootInputs)} }: (import ./setup-flake.nix).outputs inputs;
    }
  '';
  offlineSource = pkgs.runCommand "${name}-offline-source" { } ''
    mkdir "$out"
    cp -r ${self}/. "$out/"
    chmod -R u+w "$out"
    ${lib.optionalString reuseSetupOutputs ''
      cp ${setupFlakePath} "$out/setup-flake.nix"
      cp ${setupTargetFlake} "$out/flake.nix"
    ''}
    ${lib.optionalString (!reuseSetupOutputs) "cp ${targetFlake} \"$out/flake.nix\""}
    cp ${onlineLockFile} "$out/flake.online.lock"
    cp ${localLockFile} "$out/flake.lock"
  '';
in
{
  inherit inputSources offlineSource;
}
