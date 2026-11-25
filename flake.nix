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
      # Reuse NixOS' Calamares configuration and native view/storage modules.
      # Only replace the generic configuration generator with our flake adapter.
      yaml = name: value: pkgs.writeText name (builtins.toJSON value);
      calamaresSettings = yaml "settings.conf" {
        modules-search = [
          "local"
          "@out@/lib/calamares/modules"
        ];
        instances = [
          {
            module = "m5";
            id = "validate";
            config = "m5-validate.conf";
          }
          {
            module = "m5";
            id = "install";
            config = "m5-install.conf";
            weight = 50;
          }
        ];
        sequence = [
          {
            show = [
              "welcome"
              "locale"
              "keyboard"
              "users"
              "partition"
              "summary"
            ];
          }
          {
            exec = [
              "m5@validate"
              "partition"
              "mount"
              "m5@install"
              "umount"
            ];
          }
          { show = [ "finished" ]; }
        ];
        branding = "nixos";
        prompt-install = true;
        dont-chroot = false;
        oem-setup = false;
        disable-cancel = false;
        disable-cancel-during-exec = true;
        hide-back-and-next-during-exec = true;
        quit-at-end = false;
      };
      partitionSettings = yaml "partition.conf" {
        efi = {
          mountPoint = "/boot";
          recommendedSize = "1GiB";
          minimumSize = "1GiB";
          label = "EFI";
        };
        userSwapChoices = [ "none" ];
        initialSwapChoice = "none";
        initialPartitioningChoice = "none";
        allowManualPartitioning = false;
        defaultPartitionTableType = "gpt";
        luksGeneration = "luks2";
        defaultFileSystemType = "btrfs";
        availableFileSystemTypes = [ "btrfs" ];
        requiredStorageGiB = 256;
        showNotEncryptedBootMessage = true;
        enableLuksAutomatedPartitioning = true;
        preCheckEncryption = true;
        lvm = {
          enable = false;
        };
        partitionLayout = [
          {
            name = "root";
            filesystem = "btrfs";
            noEncrypt = false;
            mountPoint = "/";
            size = "100%";
          }
        ];
      };
      mountSettings = yaml "mount.conf" {
        extraMounts = [
          {
            device = "proc";
            fs = "proc";
            mountPoint = "/proc";
          }
          {
            device = "sys";
            fs = "sysfs";
            mountPoint = "/sys";
          }
          {
            device = "/dev";
            mountPoint = "/dev";
            options = [ "bind" ];
          }
          {
            device = "tmpfs";
            fs = "tmpfs";
            mountPoint = "/run";
          }
          {
            device = "/run/udev";
            mountPoint = "/run/udev";
            options = [ "bind" ];
          }
          {
            device = "efivarfs";
            fs = "efivarfs";
            mountPoint = "/sys/firmware/efi/efivars";
            efi = true;
          }
        ];
        # An empty list triggers Calamares' @/@home defaults. Explicitly mount
        # the top-level filesystem instead, with no additional subvolumes.
        btrfsSubvolumes = [
          {
            mountPoint = "/";
            subvolume = "";
          }
        ];
        mountOptions = [
          {
            filesystem = "efi";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          }
          {
            filesystem = "btrfs";
            options = [
              "compress=zstd"
              "noatime"
            ];
          }
        ];
      };
      userSettings = yaml "users.conf" {
        defaultGroups = [
          "users"
          "networkmanager"
          "wheel"
        ];
        setRootPassword = false;
        doReusePassword = false;
        doAutologin = false;
        passwordRequirements = {
          minLength = 8;
          maxLength = 128;
        };
        allowWeakPasswords = false;
        user = {
          shell = "/run/current-system/sw/bin/bash";
          forbidden_names = [
            "root"
            "gufo"
            "nixos"
            "nobody"
            "daemon"
          ];
        };
        hostname = {
          location = "None";
          writeHostsFile = false;
          forbidden_names = [ "localhost" ];
        };
      };
      installSettings = yaml "m5-install.conf" {
        stage = "install";
        source = "${self}";
        models = "${modelFiles}";
      };
      validateSettings = yaml "m5-validate.conf" { stage = "validate"; };
      calamaresExtensions = pkgs.calamares-nixos-extensions.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p $out/lib/calamares/modules/m5
          cp ${./installer/calamares/main.py} $out/lib/calamares/modules/m5/main.py
          cp ${./installer/calamares/module.desc} $out/lib/calamares/modules/m5/module.desc
          cp ${calamaresSettings} $out/etc/calamares/settings.conf
          substituteInPlace $out/etc/calamares/settings.conf --replace-fail @out@ $out
          cp ${partitionSettings} $out/etc/calamares/modules/partition.conf
          cp ${userSettings} $out/etc/calamares/modules/users.conf
          cp ${mountSettings} $out/etc/calamares/modules/mount.conf
          cp ${installSettings} $out/etc/calamares/modules/m5-install.conf
          cp ${validateSettings} $out/etc/calamares/modules/m5-validate.conf
        '';
      });
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
          specialArgs = { inherit calamaresExtensions modelFiles; };
          modules = [
            (nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix")
            ./modules/installer.nix
          ];
        };
      };
      packages.${system} = {
        calamares-extensions = calamaresExtensions;
        models = modelFiles;
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
        default = self.packages.${system}.iso;
      };
      checks.${system}.installer-tests =
        pkgs.runCommand "m5-installer-tests"
          {
            nativeBuildInputs = [
              pkgs.python3
            ];
          }
          ''
            export PYTHONDONTWRITEBYTECODE=1
            python3 ${./tests/test_calamares.py} ${./installer/calamares/main.py}
            touch "$out"
          '';
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
