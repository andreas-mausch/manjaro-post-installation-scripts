{
  description = "Reproducible BOSGAME M5 desktop and interactive LUKS installer";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gufo.url = "github:gufo-org/gufo/v0.36.0";
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
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      gufoPackage = gufo.packages.${system}.release;
      modelManifest = builtins.fromJSON (builtins.readFile ./models.lock.json);
      upstreamManifest = builtins.fromJSON (
        builtins.readFile (gufo + "/src/models/qwen38_flash_next/models.lock.json")
      );
      installer = pkgs.writeShellApplication {
        name = "install-m5";
        runtimeInputs = with pkgs; [
          python3
          util-linux
          parted
          cryptsetup
          dosfstools
          e2fsprogs
          mkpasswd
          nixos-install-tools
          coreutils
          networkmanager
          systemd
        ];
        text = ''
          export M5_SOURCE=${self}
          export M5_GUFO=${gufoPackage}/bin/gufo
          exec python3 ${./installer/install.py} "$@"
        '';
      };
    in
    assert modelManifest == upstreamManifest;
    {
      nixosConfigurations = {
        m5 = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit gufoPackage; };
          modules = [ ./modules/desktop.nix ];
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
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        default = self.packages.${system}.iso;
      };
      checks.${system}.installer-tests =
        pkgs.runCommand "m5-installer-tests"
          {
            nativeBuildInputs = [ pkgs.python3 ];
          }
          ''
            export PYTHONDONTWRITEBYTECODE=1
            python3 ${./tests/test_installer.py} ${./installer/install.py}
            touch "$out"
          '';
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
