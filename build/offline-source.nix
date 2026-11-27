{
  pkgs,
  self,
  nixpkgs,
  system,
  name,
  rootInputs,
  targetProfile,
  withAI,
  repository,
  projectSource,
  sshKeysFile,
}:
let
  lib = nixpkgs.lib;
  hasRepository = builtins.pathExists (repository + "/.git/HEAD");
  projectLock = builtins.fromJSON (builtins.readFile (self + "/flake.lock"));
  reachable =
    nodeName:
    [ nodeName ]
    ++ lib.concatMap (edge: if builtins.isString edge then reachable edge else [ ]) (
      builtins.attrValues (projectLock.nodes.${nodeName}.inputs or { })
    );
  selectedNodes = lib.unique (
    lib.concatMap (inputName: reachable projectLock.nodes.${projectLock.root}.inputs.${inputName}) (
      builtins.attrNames rootInputs
    )
  );
  originalLock = projectLock // {
    nodes = (lib.filterAttrs (nodeName: _: builtins.elem nodeName selectedNodes) projectLock.nodes) // {
      my-os-setup = {
        flake = false;
        original = {
          type = "github";
        }
        // projectSource;
        locked = {
          type = "path";
          path = self.outPath;
        };
      };
      ${projectLock.root} = {
        inputs = {
          my-os-setup = "my-os-setup";
        }
        // lib.filterAttrs (
          inputName: _: builtins.hasAttr inputName rootInputs
        ) projectLock.nodes.${projectLock.root}.inputs;
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
  inputNodes = {
    my-os-setup = self.outPath;
  }
  // builtins.listToAttrs (
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
  sourceInputs = {
    my-os-setup = {
      url = "github:${projectSource.owner}/${projectSource.repo}";
      flake = false;
    };
  }
  //
    lib.filterAttrs (inputName: _: builtins.hasAttr inputName rootInputs)
      (import (self + "/flake.nix")).inputs;
  targetFlake = pkgs.writeText "${name}-flake.nix" ''
    {
      inputs = ${lib.generators.toPretty { } sourceInputs};
      outputs = inputs@{ self, nixpkgs, my-os-setup, ${lib.optionalString withAI "gufo,"} ... }: let
        sources = map (entry: entry.key) (builtins.genericClosure {
          startSet = map (input: { key = input.outPath; inherit input; })
            (builtins.attrValues (builtins.removeAttrs inputs [ "self" ]));
          operator = entry: map (input: { key = input.outPath; inherit input; })
            (builtins.attrValues (entry.input.inputs or {}));
        });
        target = nixpkgs.lib.nixosSystem {
          system = "${system}";
          ${lib.optionalString withAI ''
            specialArgs.gufoPackage = import (my-os-setup + "/modules/generative-ai/gufo.nix") {
              pkgs = nixpkgs.legacyPackages.${system};
              inherit gufo;
              revision = gufo.shortRev or (
                if gufo.outPath == "${rootInputs.gufo.outPath}" then
                  "${rootInputs.gufo.shortRev}"
                else "dirty"
              );
            };
          ''}
          modules = [ (my-os-setup + "/profiles/${builtins.baseNameOf targetProfile}")
            ./configuration.nix
            { system.extraDependencies = sources; } ];
        };
      in {
        nixosConfigurations = { ${name} = target; default = target; }
        // {
          "''${target.config.networking.hostName}" = target;
        };
      };
    }
  '';
  offlineSource = pkgs.runCommand "${name}-offline-source" { } ''
    mkdir "$out"
    ${lib.optionalString hasRepository ''
      ln -s ${repository} "$out/repository"
    ''}
    cp ${targetFlake} "$out/flake.nix"
    cp ${localLockFile} "$out/flake.lock"
    cp ${sshKeysFile} "$out/ssh-authorized-keys"
  '';
in
{
  inherit inputSources offlineSource;
}
