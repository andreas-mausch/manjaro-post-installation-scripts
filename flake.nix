{
  description = "Reproducible BOSGAME M5 desktop and interactive LUKS installer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gufo.url = "github:gufo-org/gufo/v0.36.0";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://gufo.cachix.org" ];
    extra-trusted-public-keys = [
      "gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      gufo,
      disko,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      gufoPackage = gufo.packages.${system}.release;
      diskoPackage = disko.packages.${system}.default;
      modelManifest = builtins.fromJSON (builtins.readFile ./models.lock.json);
      upstreamManifest = builtins.fromJSON (
        builtins.readFile (gufo + "/src/models/qwen38_flash_next/models.lock.json")
      );
      modelFiles = pkgs.linkFarm "m5-models" (
        nixpkgs.lib.concatMap (
          component:
          map (file: {
            name = "flash-next-q4/${file.path}";
            path = pkgs.fetchurl {
              url = "https://huggingface.co/${component.source.hf}/resolve/${component.source.revision}/${file.path}";
              sha256 = file.sha256;
            };
          }) component.files
        ) (builtins.attrValues modelManifest.models.flash-next-q4)
      );
      installer = pkgs.writeShellApplication {
        name = "install-m5";
        runtimeInputs =
          with pkgs;
          [
            jq
            util-linux
            cryptsetup
            mkpasswd
            nixos-install-tools
            coreutils
            findutils
            networkmanager
            systemd
          ]
          ++ [ diskoPackage ];
        text = ''
          export M5_SOURCE=${self}
          export M5_MODELS=${modelFiles}
          ${builtins.readFile ./installer/install.sh}
        '';
      };
    in
    assert modelManifest == upstreamManifest;
    {
      nixosConfigurations = {
        m5 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit gufoPackage; };
          modules = [
            disko.nixosModules.disko
            ./modules/desktop.nix
          ];
        };
        installer = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit installer; };
          modules = [
            (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")
            ./modules/installer.nix
          ];
        };
      };
      packages.${system} = {
        inherit installer;
        models = modelFiles;
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        default = self.packages.${system}.iso;
      };
      checks.${system}.installer-tests =
        pkgs.runCommand "m5-installer-tests"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.shellcheck
              pkgs.jq
            ];
          }
          ''
            bash -n ${./installer/install.sh}
            shellcheck ${./installer/install.sh}
            bash ${./tests/test_installer.sh} ${./installer/install.sh}
            touch "$out"
          '';
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
