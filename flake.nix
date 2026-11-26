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
      profiles = {
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
        name: profileSpec: sources:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = nixpkgs.lib.optionalAttrs profileSpec.ai { inherit gufoPackage; };
          modules = [
            profileSpec.profile
            ./modules/target-configuration.nix
          ]
          ++ [ { system.extraDependencies = sources; } ];
        };
      mkProfile =
        name: profileSpec:
        import ./build/iso.nix {
          inherit
            pkgs
            self
            nixpkgs
            gufo
            system
            name
            profileSpec
            ;
          mkTarget = mkTarget name profileSpec;
        };
      builds = builtins.mapAttrs mkProfile profiles;
    in
    {
      nixosModules = builtins.mapAttrs (_: spec: import spec.profile) profiles // {
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
        variant-tests = import ./tests/variants.nix { inherit pkgs builds profiles; };
        reusable-module-tests = import ./tests/reusable-modules.nix {
          inherit pkgs nixpkgs gufoPackage;
          modules = self.nixosModules;
        };
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
