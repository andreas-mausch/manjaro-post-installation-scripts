{
  description = "Reproducible NixOS KDE desktop with Steam, Gufo and a graphical installer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gufo.url = "github:gufo-org/gufo/v0.36.0";
  };

  outputs =
    {
      self,
      nixpkgs,
      gufo,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      gufoPackage = import ./modules/generative-ai/gufo.nix {
        inherit pkgs gufo;
        source = self;
      };
      variants = {
        base = {
          profile = ./profiles/base.nix;
          ai = false;
        };
        desktop = {
          profile = ./profiles/desktop.nix;
          ai = false;
        };
        gaming = {
          profile = ./profiles/gaming.nix;
          ai = false;
        };
        ai = {
          profile = ./profiles/ai.nix;
          ai = true;
        };
        full = {
          profile = ./profiles/full.nix;
          ai = true;
        };
      };
      mkTarget =
        name: variant: sources:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = nixpkgs.lib.optionalAttrs variant.ai { inherit gufoPackage; };
          modules = [
            variant.profile
            ./modules/target-configuration.nix
          ]
          ++ [ { system.extraDependencies = sources; } ];
        };
      mkVariant =
        name: variant:
        let
          archive = import ./modules/installer/offline-source.nix {
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
            // nixpkgs.lib.optionalAttrs variant.ai { inherit gufo; };
            targetProfile = variant.profile;
            reuseSetupOutputs = variant.ai;
          };
          inherit (archive) inputSources offlineSource;
          # Prebuild the fixed package set and encryption-related initrd components.
          # Do not include the complete .drv/source graph (Kernel/ROCm toolchains).
          target = mkTarget name variant inputSources;
          offlineSeed = target.extendModules {
            modules = [
              {
                boot.initrd.luks.devices.cryptroot.device =
                  "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
              }
            ];
          };
          offlineSystem = offlineSeed.config.system.build.toplevel;
          offlineAssembly = with offlineSeed.config.system.build; [
            toplevel
            initialRamdisk
            initialRamdiskSecretAppender
            etc
            bootStage2
            modulesClosure
            # Include buildEnv's declared assembly dependencies as well.
            (offlineSeed.config.system.path)
          ];
          assemblyTools = nixpkgs.lib.unique (
            nixpkgs.lib.concatMap (
              drv:
              builtins.filter nixpkgs.lib.isDerivation (
                nixpkgs.lib.flatten [
                  (drv.drvAttrs.nativeBuildInputs or [ ])
                  (drv.drvAttrs.buildInputs or [ ])
                  (drv.drvAttrs.stdenv or [ ])
                ]
              )
            ) offlineAssembly
          );
          # Dynamic settings assemble config files, units and an initrd. Reuse
          # prebuilt Kernel/desktop/ROCm packages instead of recompiling them.
          offlineTools =
            assemblyTools
            ++ (with pkgs; [
              stdenvNoCC
              bash
              coreutils
              findutils
              gnugrep
              gnused
              gawk
              diffutils
              perl
              jq
              cpio
              gzip
              zstd
              xz
              kmod
              kbd
              systemd
              makeWrapper
              lndir
              # Activation and hardware-dependent initrd assembly need these
              # finished outputs, not their compiler/source dependency graphs.
              libcap-text-verifier
              # buildEnv's generated builder also references these tools outside
              # the nativeBuildInputs inspected above (Info and MIME/XML indexes).
              texinfo
              libxslt
              microcode-amd
              microcode-intel
              linux-firmware
            ])
            ++ calamares.offlinePackages;
          modelFiles = import ./modules/generative-ai/model-files.nix {
            inherit pkgs gufo;
            models = offlineSeed.config.generative-ai.models;
          };
          calamares = import ./modules/installer/calamares.nix {
            inherit pkgs offlineSource;
            lib = nixpkgs.lib;
            variantName = name;
            withModels = variant.ai;
            modelFiles = if variant.ai then modelFiles else null;
            modelsDirectory = if variant.ai then offlineSeed.config.generative-ai.models.directory else null;
          };
          inherit (calamares) calamaresExtensions welcomeModule;
          installer = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit calamaresExtensions offlineSystem offlineTools;
              modelFiles = if variant.ai then modelFiles else null;
              variantName = name;
            };
            modules = [
              (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix")
              ./modules/installer
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
        };
      builds = builtins.mapAttrs mkVariant variants;
    in
    {
      nixosModules = {
        base = import ./modules/base.nix;
        desktop = import ./modules/desktop.nix;
        gaming = import ./modules/gaming.nix;
        generative-ai = import ./modules/generative-ai;
        installer = import ./modules/installer;
      };
      nixosConfigurations =
        builtins.mapAttrs (_: build: build.target) builds
        // nixpkgs.lib.mapAttrs' (
          name: build: nixpkgs.lib.nameValuePair "installer-${name}" build.installer
        ) builds
        // {
          installer = builds.full.installer;
        }
        //
          nixpkgs.lib.optionalAttrs
            (builtins.pathExists ./configuration.nix && builtins.pathExists ./installation.json)
            (
              let
                installed = builtins.fromJSON (builtins.readFile ./installation.json);
                target = builds.${installed.variant}.target;
              in
              {
                ${target.config.networking.hostName} = target;
              }
            );
      packages.${system} =
        (nixpkgs.lib.mapAttrs' (
          name: build: nixpkgs.lib.nameValuePair "iso-${name}" build.installer.config.system.build.isoImage
        ) builds)
        // {
          calamares-extensions = builds.full.calamaresExtensions;
          calamares-welcome = builds.full.welcomeModule;
          models = builds.full.modelFiles;
          offline-source = builds.full.offlineSource;
          offline-system = builds.full.offlineSystem;
          iso = self.nixosConfigurations.installer.config.system.build.isoImage;
          default = self.packages.${system}.iso;
        };
      checks.${system} = {
        installer-tests =
          pkgs.runCommand "desktop-installer-tests"
            {
              nativeBuildInputs = [
                pkgs.python3
              ];
            }
            ''
              export PYTHONDONTWRITEBYTECODE=1
              python3 ${./tests/test_calamares.py} ${./modules/installer/calamares/main.py}
              touch "$out"
            '';
        variant-tests = import ./tests/variants.nix { inherit pkgs builds variants; };
        reusable-module-tests = import ./tests/reusable-modules.nix {
          inherit pkgs nixpkgs gufoPackage;
          modules = self.nixosModules;
        };
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
