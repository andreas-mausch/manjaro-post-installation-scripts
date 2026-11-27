{
  description = "Reproducible NixOS KDE desktop with Steam, Gufo and a graphical installer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gufo.url = "github:gufo-org/gufo";
    repository = {
      url = "path:./build";
      flake = false;
    };
    ssh-keys = {
      url = "path:./build/ssh-keys";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      gufo,
      ssh-keys,
      repository,
    }:
    let
      system = "x86_64-linux";
      projectSource = {
        owner = "andreas-mausch";
        repo = "my-os-setup";
      };
      pkgs = nixpkgs.legacyPackages.${system};
      gufoPackage = import ./modules/generative-ai/gufo.nix {
        inherit pkgs gufo;
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
            ssh-keys
            repository
            projectSource
            ;
          mkTarget = mkTarget name profileSpec;
        };
      builds = builtins.mapAttrs mkProfile profiles;
    in
    {
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
          name: build:
          nixpkgs.lib.nameValuePair "iso-${name}" (
            assert builtins.pathExists (repository + "/.git/HEAD");
            build.installer.config.system.build.isoImage
          )
        ) builds)
        // (nixpkgs.lib.mapAttrs' (
          name: build: nixpkgs.lib.nameValuePair "offline-source-${name}" build.offlineSource
        ) builds)
        // {
          calamares-extensions = builds.full.calamaresExtensions;
          calamares-welcome = builds.full.welcomeModule;
          models = builds.full.modelFiles;
          offline-source = builds.full.offlineSource;
          offline-system = builds.full.offlineSystem;
          iso = self.packages.${system}.iso-full;
          default = self.packages.${system}.iso;
        };
      checks.${system} = import ./tests {
        inherit
          pkgs
          nixpkgs
          gufoPackage
          builds
          profiles
          ;
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
