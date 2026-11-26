---
status: solved
status-description: "Solved for the tested encrypted UEFI VM; broader coverage unproven"
---

# Offline installation triggers unavailable source builds
- Resolved: 2026-11-25

## Problem

A networkless UEFI installation failed after Erase disk while downloading
`https://ftpmirror.gnu.org/bash/bash-5.3.tar.gz`. Partitioning worked; the
reported `unshare failed` described the parent invocation, not the cause.

## Investigation and unsuccessful attempts

1. The reference system's runtime closure lacked tools to assemble changed
   identity, UUIDs and initrd. Texinfo was missing for system-path construction.
   `19833a5` added prebuilt system-path, Texinfo, XML, capability, microcode
   and firmware tools without retaining the full kernel/ROCm build graph.
   Isolated plain and LUKS builds passed with changed user, locale, time zone,
   keyboard, UUIDs and VirtIO modules. Actual installation still failed on Bash.
2. `nixos-install` adds a local `auto` substituter, but our later
   `substituters = ""` replaced it. Option ordering was verified with Nix
   2.35.6. `886ef3e` removed normal-install network isolation and source,
   builder and registry overrides. Sixteen adapter tests passed, but manual
   installation still failed, including with explicit `auto?trusted=1`.
   Substituter ordering explained only part of the problem.
3. A shortened manual command omitted `build-dir` and failed on world-writable
   `/tmp`. Adding `--option build-dir /nix/var/nix/builds` reached the package
   build. This invocation mistake was not the source-download root cause.
4. Three prebuilt Bash paths existed in the live VM. Direct `nix copy` failed
   on an unsigned libgcc dependency; diagnostic copying with `--no-check-sigs`
   succeeded. The next installation failed on gnused/Python instead of Bash.
   Even diagnostic `require-sigs = false` did not fix installation: first
   downloads included Python 3.14.6, ACL 2.4.0 and attr 2.6.0. This did not
   prove those packages were absent from the ISO.
5. A separate-store dry run with `--offline` planned 13,460 builds, including
   bootstrap tools. Explicit `substitute = true` reduced this to 313, but
   restricted host-daemon settings and a disallowed local substituter made
   that run unsuitable as clean installation evidence.
6. A real separate-store reproduction also failed on Bash. Direct copying
   exposed dereferenced store symlinks and hash mismatches in the harness;
   symlinks were then preserved and the comparison repeated. The missing
   requested output was Bash's `dev`, even though its `out` existed:
   `/nix/store/02pyv1n66h4l27zv105gip35b99qrqam-bash-5.3p20-dev`.
7. The temporary dependency audit marked whole derivations as visited and
   missed later requests for other outputs of the same derivation. Tracking
   individual outputs corrected that gap. The audit also initially missed
   substitution exclusions.
8. The ISO's activation-script Perl environment
   (`7f11jkm…-perl-5.42.3-env.drv`) set `allowSubstitutes = false` in
   `structuredAttrs`. It required build dependencies even though its finished
   output existed on the ISO. `always-allow-substitutes = true` allowed offline
   assembly, first with directly copied packages, then in a fresh target store
   using only ISO paths as substitutes and no advance package copying.

## Test-harness limitations

The initial assembly tests placed packages directly in the build store and
therefore missed transfer from the live store into a separate target store.
Arch supplied Nix and libraries; `setgroups`/`uid_map` errors were namespace
limitations, so the inner sandbox was disabled while outer store/network
isolation remained. The first LUKS build reused artifacts from the plain build.

Later tests used an unprivileged target store at `/nix/store`, a separate ISO
store and blocked network. Early runs disabled signature checks and had
symlink-copy errors. These were system-build tests, not complete
`nixos-install`, boot or Calamares tests. Online installation success alone
also cannot establish offline completeness.

## Root cause and final correction

Nixpkgs' Perl-environment builder sets `preferLocalBuild = true` and
`allowSubstitutes = false` because small wrapper/assembly steps are usually
cheaper locally than cache queries. This is an optimization, not a security
requirement. In a separate offline store it forces unavailable build tools
despite the completed output being present on the ISO.

`38135af` enables `substitute` and `always-allow-substitutes` only for
`nixos-install`. It leaves installed-system defaults and signature checks
unchanged. The retained targeted assembly tools cover dynamic settings;
the full bootstrap/compiler closure is deliberately not bundled.

## Signature strategy and verification

- Manual networkless installation on Calamares-prepared partitions succeeded
  with local substitution and both substitution options. That diagnostic run
  still used `require-sigs = false`; roughly 12 GiB transferred, systemd-boot
  and UEFI entries installed, and boot without the ISO, LUKS unlock and KDE
  succeeded. A safe signature policy and native completion were still pending.
- Nix 2.35 supports source-specific `trusted=1`. `nixos-install` already uses
  `auto?trusted=1` for the live store. This trusts the ISO/live store without
  globally disabling `require-sigs`; online caches retain signature checks.
  Trusted signatures establish provenance/integrity, not build correctness.
- A fresh-store test passed with ISO paths only, blocked networking,
  `require-sigs = true` and `local?root=/mnt&trusted=1`. Realizing archived
  sources with `nix-store --realise` through that source and then building
  passed without `--no-check-sigs`. Direct `nix copy` still rejected unsigned
  sources: substituter trust is not a direct-copy signature exception. This
  test used a local substituter rather than `auto`, not a complete install.
- Finally, a newly built ISO installed entirely offline through Calamares
  without manual flags or globally disabled signatures. Boot, KDE and
  `gufo --version` succeeded; online updates, rebuild and reboot were then
  user-confirmed. This resolves the failure for that encrypted UEFI VM.
- Generalization, live logging and job splitting followed and required new
  checks. Later Full GUI/job behavior, boot and updates were user-confirmed.
  Other hardware and full offline coverage of every profile remain unproven.
  `3562679` records that additional offline regression and variant tests were
  retired by user decision, not reported as passed. Model integrity is accepted
  through pinned build-time checksums and successful copying, without an
  additional target checksum pass.

## Evidence

- Fixes: `19833a5`, `886ef3e`, `38135af`.
- Investigation: `8a801cf`, `77f68bf`, former README diagnosis timeline.
- Completion and scope: `7eb2955`, `9cf72b2`, `3562679`.
