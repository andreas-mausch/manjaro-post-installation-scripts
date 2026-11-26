{
  pkgs,
  lib,
  target,
}:
let
  # Prepare fixed packages and LUKS initrd components, not the full compiler
  # and source graph for the kernel, desktop or ROCm.
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
  assemblyTools = lib.unique (
    lib.concatMap (
      drv:
      builtins.filter lib.isDerivation (
        lib.flatten [
          (drv.drvAttrs.nativeBuildInputs or [ ])
          (drv.drvAttrs.buildInputs or [ ])
          (drv.drvAttrs.stdenv or [ ])
        ]
      )
    ) offlineAssembly
  );
  # Dynamic settings assemble config files, units and an initrd. Reuse the
  # prebuilt kernel, desktop and ROCm instead of recompiling them.
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
      # Activation and hardware-dependent initrd assembly need finished outputs,
      # not their compiler/source dependency graphs.
      libcap-text-verifier
      # buildEnv references these outside its declared nativeBuildInputs.
      texinfo
      libxslt
      # nftables validates dynamically generated rules using these in checkPhase.
      buildPackages.libredirect
      buildPackages.lklWithFirewall.lib
      buildPackages.nftables
      microcode-amd
      microcode-intel
      # Reuse the same compressed output as the system firmware bundle.
      (compressFirmwareZstd linux-firmware)
    ]);
in
{
  inherit offlineSeed offlineSystem offlineTools;
}
