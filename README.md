# Modular NixOS installer

Graphical Calamares installer for x86_64 computers with UEFI.
The entire selected drive is repartitioned after explicit confirmation.
**All existing data, including Windows, will be erased.**
The earlier ISO was installed offline with Calamares in a UEFI VM;
KDE and Gufo subsequently started. The user confirmed a successful online
update and rebuild of that installation, followed by a successful reboot.
With the new Full ISO, the user also confirmed Calamares autostart, desktop
launch through Polkit, graphical display, model selection, live logging,
model-copy progress, the new model directory and separate-job behavior.
The user also confirmed boot without the ISO, Steam/Gufo and online updating
followed by reboot with the new Full installation. This evidence does not
cover all variants or real hardware.

The project started with a Bosgame M5. The setup does not impose GPU memory
limits or force AMD drivers for that machine. Hardware drivers and CPU
microcode are selected through the hardware configuration generated during
installation. This is not a guarantee of universal hardware or offline driver
support. The pinned upstream Gufo release uses a ROCm backend for AMD Strix
Halo (`gfx1151`); other GPUs require a suitable Gufo backend or a different
build. KDE and the installer are not tied to this GPU model.

## Requirements and reproducible builds

Build definitions live under `build/`: `iso.nix` composes the live image,
`live.nix` configures its environment, `offline.nix` prepares the reference
system and assembly tools, and `offline-source.nix` archives locked inputs.
Generated build artifacts are exposed through `result/`, not stored in `build/`.
`modules/installer/` contains only the Calamares integration.

The Flake provides five predefined system profiles under `profiles/`:

| Profile | Composition                         | ISO output    | Free application packages |
| ------- | ----------------------------------- | ------------- | ------------------------- |
| Base    | `base.nix`                          | `iso-base`    | ✅                        |
| Desktop | `desktop.nix`                       | `iso-desktop` | ✅                        |
| Gaming  | `gaming.nix`                        | `iso-gaming`  | ❌ Steam                  |
| AI      | `desktop.nix` + `generative-ai/`     | `iso-ai`      | ✅                        |
| Full    | `gaming.nix` + `generative-ai/`      | `iso-full`    | ❌ Steam                  |

The last column describes Nixpkgs package permissions, not a complete license
audit: redistributable firmware is enabled in every variant; model weights
have separate licenses.

`profiles/base.nix` owns the common system policy and
`profiles/desktop.nix` extends Base with KDE, audio and Firefox;
`profiles/gaming.nix` extends Desktop with Gaming. AI extends Desktop with
the AI module, and Full extends Gaming with AI.
Base, Desktop and Gaming settings live directly in their profiles, without
separate feature-module wrappers. `modules/generative-ai/` remains independent
of Base and Desktop so it can also be used on a headless system.
Profiles and the AI module are imported directly from their file paths;
there is no additional `nixosModules` export interface. They do not import
repository-local hardware or user configuration. Consumers provide their
own filesystems and users; AI
also requires the `gufoPackage` module argument. Repository targets use the
separate `modules/target-configuration.nix` composition to load local settings
or supply the pre-install reference layout and user.
The AI module defines `generative-ai.models.directory` (default:
`/var/lib/generative-ai/models`). Gufo, directory rules and installer copying
use this same value. Changing it later does not automatically move existing
weights; those must be relocated separately.
Qwen weights reside under `text-generation/Qwen3.8-Flash-Next/UD-Q4_K_XL/`,
MTP under `text-generation/Qwen3.8-Flash-Next/MTP/`, and the projector directly
under `text-generation/Qwen3.8-Flash-Next/`. HF filenames are preserved.
Gufo uses the explicit first GGUF shard path rather than a model alias.
`generative-ai.models.text-generation.directory` derives from the model root;
`generative-ai.models.text-generation.qwen38FlashNext.directory` derives from
that directory. Each subdirectory must remain inside its respective parent.

Every live ISO includes KDE and Calamares; the Base target includes neither
KDE nor Firefox. Gaming adds Steam; AI adds Gufo and its supporting components.
Only AI/Full ISOs contain all six Qwen files and optional model copying.
Unfree packages are not allowed globally: only Gaming allows `steam` and
`steam-unwrapped` through `allowUnfreePredicate`. Redistributable firmware
remains enabled through the separate NixOS hardware option, so the setup
should not be understood as exclusively free software.
Without AI, Gufo/toolchain inputs are also removed from the installed Flake.

Targets are named `nixosConfigurations.<variant>`; installed systems also
provide a target named after `networking.hostName` for the standard
`sudo nixos-rebuild switch` command. Live configurations are
`nixosConfigurations.installer-<variant>`. `iso`, `default` and `installer`
remain aliases for Full. These names are independent of the chosen hostname.
All variants have been evaluated locally. Desktop installation and the new
Full ISO's GUI/logging/model-copy checks are user-confirmed; full offline
installation evidence for every variant remains outstanding.

Use a Linux x86_64 machine with a working Nix installation and Nix store.
The Flake does not enable `nix-command` and `flakes` for the invoking Nix;
if necessary, run the following commands with
`nix --extra-experimental-features 'nix-command flakes' …`.

```bash
nix flake lock
nix fmt
nix flake check --no-build
nix build .#checks.x86_64-linux.installer-tests
nix build .#checks.x86_64-linux.variant-tests
nix build .#iso-full
```

Version and archive `flake.lock` together with all configuration files.
The initial lock operation fixes versions; do **not** run `nix flake update`
for subsequent builds. Gufo is additionally pinned to release v0.36.0.
Gufo's separate toolchain inputs deliberately do not follow the host Nixpkgs,
so the official build and its cache remain usable.
The Gufo Cachix cache is used in addition to the NixOS cache; this also means
trusting its signed builds. Without a configured cache, large local ROCm/Gufo
builds may be necessary.

The image resides under `result/iso/` and contains the installer and locked
Flake; AI/Full additionally include all six model files. These are downloaded
during the ISO build and verified against pinned SHA-256 checksums.
On request, the installer copies them from the medium to the target without
downloading models. The models alone total roughly 115 GB; a 256 GB USB drive
is a reasonable starting point. Check the actual ISO size before writing it.
Building requires substantially more free space in the Nix store; the
repository itself is small. SquashFS compression is disabled. The offline ISO
also contains the prepared desktop system, local Flake inputs and tools for
configuration/initrd assembly.

## Preparing the USB drive

Write the ISO to the **correct USB drive**, for example with KDE ISO Image
Writer. This also erases that drive. No automatically executed write command
with a guessed device name is provided deliberately.

## Installation

1. Disable Secure Boot in the firmware. For GPU inference, also check Gufo's
   requirements for the available GPU and its memory.
2. Boot the USB drive in **UEFI mode**. The KDE live desktop automatically
   logs in as `nixos`. Ethernet or Wi-Fi is not required for the intended
   offline installation. The image does not provide SSH access.
3. Open Calamares (autostart or desktop shortcut). Select language, time zone,
   keyboard, user and password. The ISO variant fixes the target composition;
   there is no desktop selection.
4. Select the **correct SSD**, choose “Erase disk” and select the desired
   encryption setting. LUKS is selected by default but optional. When enabled,
   Calamares checks here that the passphrase is nonempty and both entries match.
   No swap. Minimum size: 256 GiB for AI/Full, otherwise 32 GiB.
   Unlike the earlier wrapper, this version uses Calamares' device selection
   without our additional USB/transport filter or a typed erase-confirmation
   phrase. Carefully check model, size and target device in the summary.
5. Accept the final installation confirmation. Before partitioning, the
   installer module validates UEFI, erase mode, no swap and user input.
   Calamares partitions, formats and mounts. “Install NixOS” then installs
   `path:/…/etc/nixos#<hostname>` using `nixos-install`. For AI/Full, the separate
   “Copy model weights” job subsequently copies selected models from the
   medium; without weights it skips copying. Wait for the Finish page;
   100% alone does not mean all final jobs have completed.
6. Reboot and remove the USB drive. If encrypted, enter the LUKS passphrase
   during boot, then log in with the chosen user password (console for Base,
   otherwise KDE).

Layout: a 1 GiB unencrypted EFI system partition and Btrfs for all remaining
space, optionally inside LUKS2. No swap or hibernation setup. The EFI partition
containing kernel and initrd remains unencrypted; this does not protect against
tampering by someone with physical access. There is no stored LUKS key or
automatic TPM unlocking. Btrfs uses `compress=zstd` and `noatime`. This initial
version has no additional subvolumes or automatic snapshot management.

Calamares requests the LUKS passphrase through a masked input; our module does
not create a key file. Only the user password hash is stored on the target SSD
at `/var/lib/nixos-secrets/user-password.hash`, never in the Nix store.
Root login is locked; the user can use `sudo` with their password.

### Calamares integration and limitations

The ISO uses the existing NixOS module
`installation-cd-graphical-calamares-plasma6.nix`, which imports
`installation-cd-graphical-calamares.nix`. KDE live desktop, Calamares, Polkit,
native views and partitioning/mount jobs therefore come from Nixpkgs.
Disko and `disko-install` are no longer used.
The compiled Calamares package is variant-independent. A separate wrapper
sets configuration paths; desktop/autostart entries and Polkit refer to that
wrapper. Installer configuration changes therefore do not recompile Calamares.

`modules/installer/calamares/main.py` only adapts our Flake: preflight checks,
user/language settings, hardware configuration, root-protected password hash,
`nixos-install` and model copying. Python is a Calamares module interface here
and is also used by the standard NixOS integration; there is no separate
interactive Python or shell installer anymore. Native user jobs are not run
because our Flake already configures users and their persistent password hash
declaratively.

Manual partitioning is disabled in this version. The pinned Nixpkgs Calamares
package contains `dont-allow-manual-luks.patch`, which removes LUKS/LUKS2 from
manual filesystem dialogs. We do not remove this patch without testing.
Automatic LUKS2 partitioning is supported.
System installation and model copying are separate Calamares job instances
with their own titles and progress weights. System-installation progress
indicates coarse phases. Model-copy progress tracks copied bytes and reports
per-file and total progress; it is not a checksum or durable-write guarantee.
Both jobs use the same adapter; a model copy error does not ask the user to
reinstall the system.

### Offline installation with dynamic settings

For AI/Full, before the summary Calamares offers **with Qwen model weights**
(selected by default) or **without model weights**. Without weights, copying
the six files to `/var/lib/generative-ai/models` is skipped, saving roughly
107 GiB on the target. The selected module composition stays unchanged.
Gufo remains manually started and needs weights provided later for model use.
Weights belong only to the live ISO, not the target-system package closure.
ISO size and build-space requirements do not change. The user confirmed the
no-copy behavior and separate-job handling; broader offline variant testing
remains outstanding.

`packages.x86_64-linux.offline-system` is a prebuilt reference system with
the Full package set and LUKS initrd components. Each ISO instead includes
its own variant's package set and runtime closure, plus the direct build tools
for system, filesystem and initrd assembly. This is **not** the full
source/compiler closure for the kernel, ROCm or the entire desktop.

The variant is recorded in `/etc/nixos/installation.json` as `variant`.
New installations generate `/etc/nixos/configuration.nix` for local settings
and import it from the target Flake. It imports the hardware configuration
and owns hostname, user, language and the existing `system.stateVersion`.
The hostname target follows `networking.hostName`; the variant target remains
available, for example `sudo nixos-rebuild switch --flake /etc/nixos#full`.
In the desktop examples below, replace
`#desktop` with the actually installed variant.

`packages.x86_64-linux.offline-source` archives all selected locked Flake inputs,
including Gufo toolchains, and rewrites their lock entries to local store paths.
Original network locks remain in `flake.online.lock`. The installed system
retains local input sources through `system.extraDependencies` so their lock
paths do not disappear after removing the USB drive or during garbage collection.
Local path inputs do not supply a short Git revision. Gufo therefore explicitly
receives the original short revision from the online lock to preserve its store
path. This was checked by comparing online/offline evaluation: every listed
system package except the newly generated `nixos-version` script had the same
store path. Offline evaluation of the archived Flake succeeded with the registry
and remote substituters disabled.

Username, hostname, keyboard, language and actual LUKS/filesystem UUIDs are still
chosen during installation. A shared archive of all supported locales prevents
a new locale build when selecting a different language. Nix rebuilds only the
system components depending on those settings; kernel, desktop and Gufo should
be reused from the local store. New packages or additional unprepared hardware
drivers are not automatically covered.

The installer lets `nixos-install` use its local `auto` substituter to transfer
store paths from the live system. Configured remote binary caches are also
allowed when a network is available. Installation should work entirely from
the ISO without a network; this must be established separately in networkless
tests. A networked installation is not evidence of offline completeness.
`--no-root-passwd` suppresses only the interactive root-password prompt;
root remains locked through `hashedPassword = "!"`, not passwordless.

Before claiming complete offline support, install the finished ISO in a UEFI VM
**without a network adapter**: choose a username and language different from
the reference, reboot, unlock LUKS, log into KDE, check Steam and the Gufo service
configuration. Model downloads are checked against the pinned manifest during
the ISO build; no additional target-file checksum pass is required. Test GPU
execution on suitable real hardware or with GPU passthrough.
Steam login, client/game updates and new system packages still require Internet
later; they are not part of offline installation.

## Using Gufo

```bash
sudo systemctl start gufo
sudo journalctl -u gufo -f
# Release GPU and model memory before demanding games:
sudo systemctl stop gufo
```

OpenAI-compatible API: `http://127.0.0.1:8080/v1`, model name `flash-next`.
The service does **not** start at boot and is not accessible on the LAN.
Configuration: one session, 32,768-token context, MTP, image projector
automatically located beside the model. Run `gufo diagnose` on actual target
hardware.

The ISO build downloads the files whose revisions, sizes and SHA-256 checksums
are pinned in this release, including MTP and the image projector.
There is no automatic model-update timer. Installed files reside outside
the Nix store at `/var/lib/generative-ai/models`.
`modules/generative-ai/models.lock.json` additionally documents these six files
in the repository; the Flake checks exact equality with the pinned Gufo release
manifest. Together they require roughly 115 GB (107 GiB) of downloads during
the ISO build, excluding games and system packages. All model downloads happen
during the ISO build; copying itself requires no network. The accepted integrity
strategy is pinned download checksums plus successful copying, without an
additional checksum pass over installed files.
Model use requires enough RAM or GPU memory and a backend supported by Gufo.
Installation and `gufo --version` alone do not prove working GPU inference.
GPU memory limits, context size and driver configuration must suit actual hardware.

## Errors and retrying model copying

Calamares displays an error message on failure. Repeating a normal installation
**erases the target drive again** after confirmation. There is no separate
interactive installer for model-only copying.

If system installation succeeded but model copying failed, manually unlock
the existing encrypted installation from the live desktop and mount it at
`/mnt`. Models are on the medium at `/etc/desktop-installer/models`; copy them
with `cp -rL` so store symlinks do not end up on the target.
Destination: `/mnt/var/lib/generative-ai/models`. Then assign the files to
`gufo:gufo` on the target and set read/write permissions as in the installation
job. First verify that `/mnt` really is the unlocked target installation.

Alternatively download the six pinned files from
`modules/generative-ai/models.lock.json` and verify its checksums. Preserve
the directory structure described above and HF filenames.
`gufo model install flash-next-q4` uses Gufo's own alias-based directory layout
and does not directly replace this procedure.

## Changing the system later

### Applying changes from this repository

No reinstallation or new ISO is necessary: a rebuild applies new tools,
services and modules. Personal files remain intact; services may restart.
Kernel changes may require a reboot. A rebuild is not a substitute for backups.

`nix flake update` updates only Flake dependencies, not our module files.
The Flake installed under `/etc/nixos` is an archived copy, not an automatically
configured Git checkout. Apply project changes separately through your own
checkout, for example at `~/coding/nixos-setup`.

**The checkout must contain the data for this exact target PC.** Our modules
read local configuration files relative to the Flake. The checkout needs
`configuration.nix`, `hardware-configuration.nix` and `installation.json`.
Without these files, evaluation defaults replace actual disk UUIDs and user
identity. Before the first rebuild from the checkout, copy the existing files
(inspect any existing local files first):

```bash
cd ~/coding/nixos-setup
cp /etc/nixos/hardware-configuration.nix .
cp /etc/nixos/installation.json .
cp /etc/nixos/configuration.nix .
sudo nixos-rebuild switch --flake "path:$HOME/coding/nixos-setup#desktop"
```

Replace `#desktop` with the installed or deliberately chosen variant.
The password hash remains on the target PC at
`/var/lib/nixos-secrets/user-password.hash`; do not copy it into the repository.
Hardware and installation metadata are deliberately Git-ignored. Keep local
PC configuration out of shared project commits as well. Therefore **use `path:`**
here: a checkout automatically treated as a Git Flake would omit ignored or
untracked files from the source. Rebuilding without them is not the correct
workflow for this setup.

Later, after reviewing project changes, run `git pull --ff-only` in the checkout
(account for local changes first) and repeat the same rebuild. Optionally run
`nix flake update` as well to update dependencies. For a reproducible published
project version, use its `flake.lock`.

Rebuilding does not automatically copy the checkout to `/etc/nixos`.
Continue using the same configuration source for later updates; otherwise a
rebuild from `/etc/nixos` could reactivate the old version. This repository-update
workflow is documented but has not yet been tested in the existing VM.

### Online updates after offline installation

The generated target Flake has no cache settings under `nixConfig`.
AI/Full systems already configure the Gufo cache and signing key in the Nix
daemon through the AI module; updates therefore require no additional Flake
configuration approval. The development Flake also has no `nixConfig`;
the build host configures the optional cache itself (see below).

Offline installation does not prevent later online updates. The archived
`flake.lock` initially pins inputs to local store paths so installation need
not download sources. Original GitHub URLs in `flake.nix` remain unchanged.
`nix flake update` resolves them again and replaces local locks with current
network locks. `flake.online.lock` backs up the original online state; it is
not a prerequisite for updating.

On the installed system with an Internet connection:

```bash
cd /etc/nixos
sudo cp flake.lock flake.before-update.lock
sudo nix flake update
sudo nixos-rebuild switch --flake path:/etc/nixos#desktop
```

This updates all Flake inputs within their specified branches or tags.
The Nixpkgs input follows `nixos-unstable`: it updates the package versions
included there, not necessarily every latest upstream release.
Updates may download sources and packages online; network isolation applies
only to offline tests, not normal installations.

Gufo is explicitly pinned to `github:gufo-org/gufo/v0.36.0` in `flake.nix`.
For a newer version, first enter the desired release tag there, then run the
update/rebuild commands above. New releases may have different configuration
options or model requirements. `nix flake update` does not update model weights
in `modules/generative-ai/models.lock.json` or files already copied to
`/var/lib/generative-ai/models`.

If an update build fails, restore the previous lock; a build failure leaves
the currently activated system intact:

```bash
sudo cp /etc/nixos/flake.before-update.lock /etc/nixos/flake.lock
```

After successful activation, use `sudo nixos-rebuild switch --rollback` to return
to the previous system generation if problems arise. This does not restore
configuration files or the lock; use corresponding backups or Git versions.

The online-update workflow for the earlier installed offline Flake was tested
in the existing VM on 2026-11-25: GitHub inputs were fetched and
`nixos-rebuild switch` succeeded (user confirmation). This evidence does not
yet cover the subsequently generalized repository configuration. The command
was run from `/etc/nixos` with `--flake .#m5`; the subsequent reboot also succeeded
(user confirmation).

### Diagnosing installation failures

#### Offline installation issue and attempted fixes (2026-11-25)

- **Symptom:** A networkless UEFI installation failed after “Erase disk” during
  the system build while downloading `https://ftpmirror.gnu.org/bash/bash-5.3.tar.gz`.
  Partitioning worked; “unshare failed” was only an imprecise message about the
  parent invocation, not the cause.
- **First identified gap:** Runtime dependencies of the reference system were
  insufficient to assemble changed identity, UUIDs and initrd; among other
  things, Texinfo was missing for system-path construction.
- **First attempted fix:** Add prebuilt system-path, Texinfo, XML and capability
  tools, AMD microcode and firmware (`19833a5`). Do not bundle the complete
  source/compiler build graph for kernel/ROCm.
- **Partial evidence:** Isolated system builds with/without LUKS passed with
  different identity, language, time zone, keyboard, UUIDs and VirtIO modules.
  Only intended ISO dependencies and archived inputs were in the test store;
  no host store or network. The LUKS variant used the same store and shared artifacts.
- **Test setup:** Arch provided Nix and libraries. Failures at `setgroups`/`uid_map`
  were harness issues, so the inner Nix sandbox was disabled while outer
  store/network isolation remained active.
- **Result with the new ISO:** Actual `nixos-install` still failed on Bash.
  A passing system build was not installation or boot evidence.
- **Further cause:** `nixos-install` first adds the local `auto` substituter;
  our later `substituters = ""` overwrote it. Even existing ISO packages were
  therefore not reused as substitutes. Option-order behavior was checked with
  Nix 2.35.6.
- **Why the test missed it:** Packages were directly in the build store;
  transfer from the live store to a separate target store was not tested.
- **Correction at that stage:** Remove network isolation and substituter,
  builder and registry restrictions from normal installation. Allow the local
  ISO store and configured online caches; without networking the ISO must still suffice.
- **Validation at that stage:** 16 adapter tests and formatting passed. The
  correction was not yet in the ISO; a complete networkless installation, boot
  and subsequent online update remained unconfirmed.
- **Live test of the correction:** Manual `nixos-install` on the still-mounted
  target also failed without the original restrictions. Explicitly setting
  only `auto?trusted=1` did not fix it. Option ordering therefore did not
  explain the entire installation failure.
- **Another invocation error:** A shortened manual command omitted `build-dir`
  and failed on world-writable `/tmp`. With
  `--option build-dir /nix/var/nix/builds`, it reached the package build.
- **Direct store transfer:** Three prebuilt Bash paths were present in the VM.
  `nix copy` into the target store initially failed on a `libgcc` dependency
  without a trusted signature; copying with `--no-check-sigs` succeeded.
  The next installation attempt failed on gnused/Python instead of Bash.
- **Signature test:** Even `--option require-sigs false` during the networkless
  installation was insufficient. First errors involved source downloads for
  Python 3.14.6, ACL 2.4.0 and attr 2.6.0. Do not change persistent signature
  checks; this test did not prove these packages were missing from the ISO.
- **Investigation at that stage:** Reproduce a separate target store instead
  of providing packages directly in the build store. A dry run with `--offline`
  planned 13,460 builds including bootstrap tools; explicit `substitute = true`
  reduced this to 313. The second run reported restricted settings and a
  disallowed local substituter at the host daemon, so it was not clean
  installation evidence. Nix's automatic disabling of substitution without
  a network still needed investigation.
- **Further work:** Reproducibly test the real installation path with a separate
  target store and blocked network before ISO releases. Manual tool lists may
  develop gaps after updates; improve derivation. Online success does not
  prove offline completeness.
- **Local reproduction attempt:** A real build with separate stores, only ISO
  paths as a local package source and blocked networking also failed on the
  Bash source download. Not yet clean evidence: subsequent direct copying
  exposed dereferenced store symlinks in the harness (hash mismatch). Symlinks
  were then reproduced unchanged and the comparison rerun. Signature checks
  were disabled for that test. It was not a complete `nixos-install`/boot test:
  the target store was at `/nix/store` inside an unprivileged namespace, with
  a separate ISO store; the inner Nix sandbox was disabled due to host namespace limits.
- **Specific missing output:** The log also requested Bash's `dev` output,
  `/nix/store/02pyv1n66h4l27zv105gip35b99qrqam-bash-5.3p20-dev`, absent from the
  ISO manifest although Bash's `out` was present. Trace the triggering parent
  build branch instead of bundling the entire bootstrap.
- **Audit gap:** The temporary graph comparison marked entire derivations as
  visited and missed later requests for additional outputs of the same
  derivation. Analysis then tracked individual outputs; a verified installer
  fix was still outstanding.
- **Confirmed substitution exclusion:** The ISO's activation-script Perl
  environment (`7f11jkm…-perl-5.42.3-env.drv`) explicitly set
  `allowSubstitutes = false` in `structuredAttrs`. Nix then required build
  dependencies instead of reusing the finished output. The graph comparison
  also missed this exclusion. A local comparison with
  `always-allow-substitutes = true` successfully built the target offline.
  The store initially contained directly copied ISO packages; repeating with
  a fresh target store and no advance copying also passed, using only actual
  ISO paths as the source and blocked networking. Signature checks were off;
  the signature strategy, real installation and boot remained to be tested.
- **Why this restriction exists:** Not Perl itself, but Nixpkgs' Perl-environment
  builder sets `preferLocalBuild = true` and `allowSubstitutes = false`.
  The environment combines finished packages and generates wrappers. Such
  small assembly steps are usually intended to be cheaper locally than cache
  queries and downloads; this is an optimization, not a security requirement.
  In a separate offline target store it forces extra build tools even though
  the finished result exists on the ISO. `always-allow-substitutes` overrides
  the exclusion without disabling independent signature checks. Hashes and
  trusted signatures protect integrity and signed provenance, but do not
  independently prove build correctness.
- **VM evidence:** Manual networkless `nixos-install` on Calamares-prepared
  partitions passed with a local substituter, `substitute = true` and
  `always-allow-substitutes = true`; `require-sigs = false` remained set only
  for this diagnostic run. Roughly 12 GiB were transferred, systemd-boot and
  UEFI entries installed, and `installation finished!` reported. Boot without
  the ISO, LUKS unlocking and the KDE desktop then succeeded. Evidence covered
  this encrypted VM variant, not arbitrary hardware.
- **Still open after VM success:** Integrate options cleanly in the installer,
  safely transfer unsigned ISO packages without globally disabling signature
  checks, add an automated regression test, complete Calamares without manual
  commands and test online updating. The existing ISO remained unchanged.
- **Signature strategy:** Nix 2.35 permits unsigned substitutes from a specific
  source through the store parameter `trusted=1`. `nixos-install` already sets
  `auto?trusted=1` for the local live store. No global disabling of `require-sigs`
  or extra adapter signature exception is needed; online caches retain normal
  signature checks. This trust requires a trusted ISO and an untampered live store.
- **Local signature test:** A fresh target store, ISO paths only, no network,
  `require-sigs = true` and `local?root=/mnt&trusted=1`: system build passed.
  The full sequence without `--no-check-sigs` also passed: first transfer the
  Flake archive and inputs with `nix-store --realise` through that same trusted
  local substituter, then build the target. Direct `nix copy` without a
  signature exception instead failed on unsigned Flake inputs; source-specific
  substituter trust does not automatically apply to direct copying. The test
  used the local-store variant rather than `auto` and was not a complete
  installation test. Source transfer in the actual `nixos-install` path still
  required separate validation.
- **Final VM test:** A newly built ISO was installed entirely offline through
  Calamares without manual flags or global disabling of signatures. Subsequent
  boot, KDE and `gufo --version` succeeded. Online input updates, rebuild and
  reboot also succeeded (user confirmation). Generalization, live logging and
  separate jobs changed afterward and required a new ISO test. Other hardware,
  language and model variants and full verification of all six weights remained open.

#### Requirements and diagnostic output

The separate `uefiwelcome` module reports mandatory UEFI support on the welcome
page. BIOS boot keeps “Next” blocked and requests rebooting the installation
medium in UEFI mode (UEFI/OVMF for VMs). The later installer preflight check
remains active as well. No BIOS fallback is planned. Early validation still
needs VM confirmation. The C++ module loads the unchanged Calamares welcome
page and extends its requirements through the official ViewStep interface.
There is no extra page or project-specific Calamares source patch.

On errors, the installer job names the phase and either the specific validation
reason or program name with exit code. For `unshare` and `nixos-install`, it
instead names the system-installation invocation: an exit code alone does not
distinguish wrapper and child-process failures. Target mounts, configuration,
user access, system installation and model copying have separate diagnostic
phases. Operating-system errors include errno. Command arguments, passwords
and hashes are excluded from these diagnostics. Every adapter command is
logged in Calamares output only by its program name.
`nixos-install` uses Calamares' public process interface to stream its output
to the Calamares logger during execution. Display under “Toggle log” is
user-confirmed with the new Full ISO. Password and configuration commands are
excluded from this streaming. Other subprocess output still uses inherited
stdout/stderr; that alone does not make it visible in the UI log.
Original output is not sanitized; inspect it for sensitive data before sharing.
Nothing is uploaded automatically. The error dialog provides a journal command
starting at the adapter invocation time. Check the first error, not only later
Nix dependency failures. Installation-job errors explicitly warn that the
target has already been partitioned and installation is incomplete, even if
preflight fails again. For the automatically started installer, read the live
VM journal with `sudo journalctl -b --no-pager` and search for
`Desktop installer`. Do not reboot the VM before saving diagnostics.
For a manually started installer, save its terminal output.

### Changing configuration without updating packages

The installer copies the setup to `/etc/nixos` and generates:

- `configuration.nix`: editable local settings, including hostname, user and language.
- `hardware-configuration.nix`: hardware, filesystems and LUKS UUIDs, imported by the local configuration.
- `installation.json`: installation metadata and selected variant.

These files are not secrets, but contain PC-specific data. On new installations,
edit `configuration.nix` for local additions rather than modifying shared modules.
A normal `nixos-rebuild` does not partition or format anything.

```bash
sudo nano /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

If this later becomes a Git repository, explicitly include generated files or
continue using `path:/etc/nixos`. The password hash stays outside the repository.
For password changes, replace the root-protected hash file;
`users.mutableUsers = false` means a plain `passwd` command does not make a
persistent configuration change.

Package versions, configuration and model selection are reproducible, not
bit-identical SSD contents. UUIDs, LUKS salts and password salts are newly
generated per installation. Steam updates its client and games independently
of Nix. Long-term repeatability still requires available downloads or your own
archive of packages and models.

## Installer choice: do not use nixos-wizard yet

Reviewed on 2026-11-25: [km-clay/nixos-wizard](https://github.com/km-clay/nixos-wizard)
has a suitable TUI for SSD selection, partitioning and user creation, but does
not yet install an existing Flake such as our desktop configuration.
Reviewed commit: `386def227ec27ea61bdfd9c3e7afeab7da39102a`.

- A “Source Flake” menu requests a local or remote Flake path.
- The path is saved but appears in the configuration preview only in the unused
  `_flake_path` field.
- Actual installation copies its own generated `configuration.nix` and invokes
  `nixos-install --root /mnt` **without `--flake`**. Entering our Flake would
  therefore not install our configuration.
- The latest `main` commit had a committer date of 2026-04-07, over seven months
  before review. That alone does not prove abandonment; combined with the
  incomplete Flake path, however, it is a reason not to use this installer
  for our use case yet.

Sources at the reviewed commit:
[Source Flake input](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L799-L1023),
[configuration preview](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4117-L4203),
[installation commands](https://github.com/km-clay/nixos-wizard/blob/386def227ec27ea61bdfd9c3e7afeab7da39102a/src/installer/mod.rs#L4532-L4603)
and [commit](https://github.com/km-clay/nixos-wizard/commit/386def227ec27ea61bdfd9c3e7afeab7da39102a).

At the time of review we therefore used `disko-install` with a wrapper.
We now use Calamares with a Flake adapter. Reassess nixos-wizard once working
Flake support is available.

## Current build environment

With a daemon-based Nix store at `/nix/store` and `nix-command` and `flakes`
enabled, build the ISO with:

```bash
nix build .#iso
```

The Gufo cache is optional. Builds still work without it, but may require a
large local Gufo/ROCm build.

### Configuring the Gufo cache in the Nix daemon

On a NixOS build host, import the shared definition in a system module
(adjust the absolute path to your checkout):

```nix
{
  nix.settings = import /path/to/repository/modules/generative-ai/cache.nix;
}
```

Then activate the system configuration with `sudo nixos-rebuild switch`.
On other distributions, generate entries from the same file:

```bash
nix eval --json --file modules/generative-ai/cache.nix \
  | jq -r 'to_entries[] | "\(.key) = \(.value | join(" "))"'
```

Merge the output with existing entries in `/etc/nix/nix.conf`.
The definition adds the cache and signing key without replacing Nix defaults.
Neither `trusted-users` nor automatic Flake configuration approval is needed.
This means trusting build results signed by the Gufo cache.

**Do not restart the daemon during an ISO build.** Wait for all running Nix
builds to finish, then:

```bash
sudo systemctl restart nix-daemon.service
nix build .#offline-system --dry-run
```

Then check whether Gufo/ROCm will be fetched from the cache where available.
Configuration alone does not guarantee a cached result for every locked derivation.
