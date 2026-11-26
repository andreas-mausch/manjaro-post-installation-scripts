{
  pkgs,
  self,
  nixpkgs,
  system,
  name,
  rootInputs,
  targetProfile,
  reuseSetupOutputs,
  sshKeysFile,
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
        (builtins.removeAttrs node [ "parent" ])
        // {
          locked = {
            type = "path";
            path = inputNodes.${nodeName};
          }
          // lib.optionalAttrs (node.locked ? narHash) {
            narHash = node.locked.narHash;
          };
        }
      else
        node
    ) originalLock.nodes;
  };
  localLockTemplate = pkgs.writeText "desktop-offline-flake-template.json" (
    builtins.toJSON localLock
  );
  # Hash relative inputs during the build, not with an unlocked fetchTree in
  # pure evaluation. Referencing inputSources also retains sandbox access.
  localLockFile =
    pkgs.runCommand "desktop-offline-flake.lock"
      {
        nativeBuildInputs = [
          pkgs.nix
          pkgs.python3
        ];
        inherit inputSources;
      }
      ''
        python3 - ${localLockTemplate} "$out" <<'PY'
        import json
        import subprocess
        import sys

        with open(sys.argv[1]) as source:
            lock = json.load(source)
        for node in lock["nodes"].values():
            locked = node.get("locked", {})
            if locked.get("type") == "path" and "narHash" not in locked:
                locked["narHash"] = subprocess.check_output(
                    ["nix", "--extra-experimental-features", "nix-command",
                     "hash", "path", "--sri", locked["path"]], text=True
                ).strip()
        with open(sys.argv[2], "w") as destination:
            json.dump(lock, destination)
        PY
      '';
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
      outputs = { self, nixpkgs, ... }: let
        target = nixpkgs.lib.nixosSystem {
          system = "${system}";
          modules = [ ./profiles/${builtins.baseNameOf targetProfile}
            ./modules/target-configuration.nix
            { system.extraDependencies = [ nixpkgs.outPath ]; } ];
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
    cp ${sshKeysFile} "$out/ssh-authorized-keys"
  '';
in
{
  inherit inputSources offlineSource;
}
