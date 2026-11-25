{
  description = "Reproducible NixOS KDE desktop with Steam, Gufo and a graphical installer";

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
      releaseLock = builtins.fromJSON (
        builtins.readFile (
          if builtins.pathExists ./flake.online.lock then ./flake.online.lock else ./flake.lock
        )
      );
      gufoRevision =
        gufo.shortRev or (builtins.substring 0 7
          releaseLock.nodes.${releaseLock.nodes.${releaseLock.root}.inputs.gufo}.locked.rev
        );
      # Local path inputs lack shortRev. Preserve Gufo's revision-dependent
      # build arguments so offline evaluation reuses the exact release package.
      gufoPackage = gufo.packages.${system}.release.override { revision = gufoRevision; };
      # Archive every locked input, including Gufo's independent toolchains.
      # Local path locks do not depend on the live image's fetcher-cache DB.
      variants = {
        base = {
          modules = [ ./modules/base.nix ];
          ai = false;
        };
        desktop = {
          modules = [ ./modules/desktop.nix ];
          ai = false;
        };
        gaming = {
          modules = [ ./modules/gaming.nix ];
          ai = false;
        };
        ai = {
          modules = [
            ./modules/desktop.nix
            ./modules/generative-ai
          ];
          ai = true;
        };
        full = {
          modules = [
            ./modules/gaming.nix
            ./modules/generative-ai
          ];
          ai = true;
        };
      };
      mkTarget =
        name: variant: sources:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = nixpkgs.lib.optionalAttrs variant.ai { inherit gufoPackage; };
          modules = variant.modules ++ [ { system.extraDependencies = sources; } ];
        };
      mkVariant =
        name: variant:
        let
          fullLock = builtins.fromJSON (builtins.readFile ./flake.lock);
          reachable =
            nodeName:
            [ nodeName ]
            ++ nixpkgs.lib.concatMap (edge: if builtins.isString edge then reachable edge else [ ]) (
              builtins.attrValues (fullLock.nodes.${nodeName}.inputs or { })
            );
          selectedNodes = reachable fullLock.nodes.${fullLock.root}.inputs.nixpkgs;
          originalLock =
            if variant.ai then
              fullLock
            else
              fullLock
              // {
                nodes =
                  (nixpkgs.lib.filterAttrs (nodeName: _: builtins.elem nodeName selectedNodes) fullLock.nodes)
                  // {
                    ${fullLock.root} = {
                      inputs = { inherit (fullLock.nodes.${fullLock.root}.inputs) nixpkgs; };
                    };
                  };
              };
          rootInputs = {
            inherit nixpkgs;
          }
          // nixpkgs.lib.optionalAttrs variant.ai { inherit gufo; };
          collectInputNodes =
            nodeName: input:
            [
              {
                name = nodeName;
                value = input.outPath;
              }
            ]
            ++ nixpkgs.lib.concatMap (
              inputName:
              let
                edge = originalLock.nodes.${nodeName}.inputs.${inputName};
              in
              if builtins.isString edge then collectInputNodes edge input.inputs.${inputName} else [ ]
            ) (builtins.attrNames (originalLock.nodes.${nodeName}.inputs or { }));
          inputNodes = builtins.listToAttrs (
            nixpkgs.lib.concatMap (
              inputName:
              collectInputNodes originalLock.nodes.${originalLock.root}.inputs.${inputName}
                rootInputs.${inputName}
            ) (builtins.attrNames rootInputs)
          );
          inputSources = nixpkgs.lib.unique (builtins.attrValues inputNodes);
          localLock = originalLock // {
            nodes = builtins.mapAttrs (
              name: node:
              if node ? locked then
                node
                // {
                  locked = {
                    type = "path";
                    path = inputNodes.${name};
                    narHash = node.locked.narHash;
                  };
                }
              else
                node
            ) originalLock.nodes;
          };
          localLockFile = pkgs.writeText "desktop-offline-flake.lock" (builtins.toJSON localLock);
          targetFlake = pkgs.writeText "${name}-flake.nix" ''
            {
              inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
              outputs = { self, nixpkgs }: {
                nixosConfigurations.${name} = nixpkgs.lib.nixosSystem {
                  system = "${system}";
                  modules = [ ${
                    nixpkgs.lib.concatMapStringsSep " " (
                      module: "./modules/${builtins.baseNameOf module}"
                    ) variant.modules
                  } { system.extraDependencies = [ nixpkgs.outPath ]; } ];
                };
              };
            }
          '';
          onlineLockFile = pkgs.writeText "${name}-online-flake.lock" (builtins.toJSON originalLock);
          offlineSource = pkgs.runCommand "${name}-offline-source" { } ''
            mkdir "$out"
            cp -r ${self}/. "$out/"
            chmod -R u+w "$out"
            ${nixpkgs.lib.optionalString (!variant.ai) "cp ${targetFlake} \"$out/flake.nix\""}
            cp ${onlineLockFile} "$out/flake.online.lock"
            cp ${localLockFile} "$out/flake.lock"
          '';
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
            ]);
          modelManifest = builtins.fromJSON (builtins.readFile ./modules/generative-ai/models.lock.json);
          upstreamManifest = builtins.fromJSON (
            builtins.readFile (gufo + "/src/models/qwen38_flash_next/models.lock.json")
          );
          modelFiles =
            assert modelManifest == upstreamManifest;
            pkgs.linkFarm "qwen-models" (
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
                module = "uefiwelcome";
                id = "uefiwelcome";
                config = "welcome.conf";
              }
              {
                module = "desktop";
                id = "validate";
                config = "desktop-validate.conf";
              }
              {
                module = "desktop";
                id = "install";
                config = "desktop-install.conf";
                weight = 50;
              }
            ]
            ++ nixpkgs.lib.optionals variant.ai [
              {
                module = "packagechooser";
                id = "models";
                config = "desktop-models.conf";
              }
              {
                module = "desktop";
                id = "models";
                config = "desktop-copy-models.conf";
                weight = 50;
              }
            ];
            sequence = [
              {
                show = [
                  "uefiwelcome"
                  "locale"
                  "keyboard"
                  "users"
                  "partition"
                ]
                ++ nixpkgs.lib.optional variant.ai "packagechooser@models"
                ++ [ "summary" ];
              }
              {
                exec = [
                  "desktop@validate"
                  "partition"
                  "mount"
                  "desktop@install"
                ]
                ++ nixpkgs.lib.optional variant.ai "desktop@models"
                ++ [ "umount" ];
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
          modelSettings = yaml "desktop-models.conf" {
            mode = "required";
            method = "legacy";
            default = "qwen";
            labels.step = "Model Weights";
            labels."step[de]" = "Modellgewichte";
            items = [
              {
                id = "qwen";
                name = "Qwen3.8-Flash-Next (GGUF, UD-Q4_K_XL)";
                "name[de]" = "Qwen3.8-Flash-Next (GGUF, UD-Q4_K_XL)";
                description = "Unsloth weights including MTP (Q8_0) and the multimodal projector (BF16): copy all six files to the target system offline. Requires about 107 GiB of additional storage.";
                "description[de]" =
                  "Unsloth-Gewichte inklusive MTP (Q8_0) und multimodalem Projektor (BF16): alle sechs Dateien offline auf das Zielsystem kopieren. Benötigt etwa 107 GiB zusätzlichen Speicherplatz.";
                screenshot = "";
              }
              {
                id = "without-models";
                name = "Without model weights";
                "name[de]" = "Ohne Modellgewichte";
                description = "Install the selected system with Gufo without copying weights. To use the model, provide its weights later.";
                "description[de]" =
                  "Das gewählte System mit Gufo installieren, ohne Gewichte zu kopieren. Für die Modellnutzung müssen die Gewichte später bereitgestellt werden.";
                screenshot = "";
              }
            ];
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
            requiredStorageGiB = if variant.ai then 256 else 32;
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
          installSettings = yaml "desktop-install.conf" {
            stage = "install";
            source = "${offlineSource}";
            target = name;
            withModels = variant.ai;
          };
          copyModelSettings = yaml "desktop-copy-models.conf" {
            stage = "models";
            models = "${modelFiles}";
          };
          validateSettings = yaml "desktop-validate.conf" {
            stage = "validate";
            withModels = variant.ai;
          };
          welcomeModule = pkgs.stdenv.mkDerivation {
            pname = "calamares-uefi-welcome";
            version = "1";
            src = ./modules/installer/calamares/welcome;
            nativeBuildInputs = [
              pkgs.cmake
              pkgs.qt6.wrapQtAppsHook
            ];
            buildInputs = [ pkgs.calamares ] ++ pkgs.calamares.buildInputs;
            dontWrapQtApps = true;
            cmakeFlags = [
              "-DUPSTREAM_WELCOME=${pkgs.calamares}/lib/calamares/modules/welcome/libcalamares_viewmodule_welcome.so"
            ];
          };
          calamaresExtensions = pkgs.calamares-nixos-extensions.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              mkdir -p $out/lib/calamares/modules/desktop
              cp -r ${welcomeModule}/lib/calamares/modules/uefiwelcome $out/lib/calamares/modules/
              cp ${./modules/installer/calamares/main.py} $out/lib/calamares/modules/desktop/main.py
              mkdir -p $out/lib/calamares/modules/desktop/locale/de/LC_MESSAGES
              ${pkgs.gettext}/bin/msgfmt --check ${./modules/installer/calamares/locale/de.po} \
                -o $out/lib/calamares/modules/desktop/locale/de/LC_MESSAGES/desktop-installer.mo
              cp ${./modules/installer/calamares/module.desc} $out/lib/calamares/modules/desktop/module.desc
              cp ${calamaresSettings} $out/etc/calamares/settings.conf
              # Offline installation must not be blocked by upstream's Internet check.
              sed -i '/^[[:space:]]*- internet$/d' $out/etc/calamares/modules/welcome.conf
              substituteInPlace $out/etc/calamares/settings.conf --replace-fail @out@ $out
              cp ${partitionSettings} $out/etc/calamares/modules/partition.conf
              cp ${userSettings} $out/etc/calamares/modules/users.conf
              cp ${mountSettings} $out/etc/calamares/modules/mount.conf
              ${nixpkgs.lib.optionalString variant.ai ''
                cp ${modelSettings} $out/etc/calamares/modules/desktop-models.conf
                cp ${copyModelSettings} $out/etc/calamares/modules/desktop-copy-models.conf
              ''}
              cp ${installSettings} $out/etc/calamares/modules/desktop-install.conf
              cp ${validateSettings} $out/etc/calamares/modules/desktop-validate.conf
            '';
          });
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
        };
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
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
