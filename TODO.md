# Preparation

Status: The user confirmed the new Full ISO's GUI startup, model selection, live logging, model-copy progress, new model directory, separate-job behavior, boot without the ISO, Steam/Gufo and online update followed by reboot. Model integrity is accepted based on pinned download checksums during the ISO build and successful copying; no additional target-file checksum pass is required. Evidence covers this VM configuration, not every variant or arbitrary hardware.

## Further preparation

Priority order:

Repository updates are the current first priority, ahead of SSH provisioning
and hardware verification. Existing section numbers remain stable for links.

2. [Repository-update workflow implementation and testing](#2-repository-updates)
4. [Secure SSH provisioning access](#4-ssh-provisioning)
1. [Full ISO verification on real hardware](#1-full-iso-verification)
3. [Release version tags](#3-release-version-tags)
5. [TUI installer](#5-tui-installer)
6. [UKI boot](#6-uki-boot)
7. [SBOM outputs](#7-sboms)
8. [Alternative model sources](#8-alternative-model-sources)
9. [Favorite programs and configuration](#9-favorite-programs)
10. [Manual partitioning](#10-manual-partitioning)
11. [Time synchronization](#11-time-synchronization)
12. [Automatic Gufo updates and verification](#12-gufo-updates)
13. [Verified Git source fetching](#13-verified-fetches)

Reusable libvirt images remain additional work after these priorities.

### 1. Full ISO verification

- [ ] Verify the Full ISO on the Bosgame M5: install without network access, verify boot and deployed programs, and test Bluetooth and compressed-only firmware usability during offline installation. Complete real-hardware inference verification in [the Gufo backend issue](docs/issues/2026-11-25_gufo-hardware-backend-validation.md).

### 2. Repository updates

- [ ] Implement and validate the host-independent repository-update workflow described in [the repository-update issue](docs/issues/2026-11-25_installed-system-repository-updates.md).
  - Implementation now generates the independent local Flake and offline lock,
    imports profiles through a non-Flake source input, and provisions the Git
    checkout from an explicitly supplied temporary Git folder. Focused installer/Git tests and
    offline Desktop/AI/Full evaluation cover host preservation and source overrides.
    Desktop VM offline rebuild, local fallback/reboot, GitHub update/reboot and
    rollback/reboot are confirmed (2026-11-27). Migration, explicit host-setting
    preservation checks, SSH access and real-hardware validation remain open.
  - Keep local host configuration under `/etc/nixos` and place the shared,
    root-managed Git checkout under `/etc/nixos/my-os-setup`. Provide a small,
    real local `/etc/nixos/flake.nix` that composes reusable project modules with
    local configuration and hardware settings; do not symlink the project Flake
    or use its reference system as the host configuration.
    By default, consume the repository as a non-Flake source input with
    `inputs.my-os-setup.url = "github:andreas-mausch/my-os-setup"` and
    `inputs.my-os-setup.flake = false`, not through the local checkout. Import
    the selected profile (for example `${my-os-setup}/profiles/desktop.nix`)
    from that source without evaluating the project's `flake.nix` or importing
    its dependency graph. Keep the project Flake for ISO builds and tests.
    Retain the checkout as an administrator-controlled fallback and development
    source.
  - Have the installer provision this layout completely: after installation,
    `/etc/nixos/my-os-setup` must already be a usable Git checkout with the
    intended remote and installed project revision, and the local Flake and host
    files must be ready for the pull/rebuild workflow without manual setup.
    Bundle a Git repository at the exact project revision used to build the ISO
    and clone it locally into the target checkout without fetching newer code
    during installation. Configure a named
    update branch and its remote/upstream at that commit, not a detached HEAD,
    so later pulls can advance from the ISO's project state.
    Preserve offline installation support and validate the first online pull
    and rebuild after installation.
  - Provide a safe migration from existing archived installations, preserving
    host configuration, hardware settings, installation metadata and SSH public
    keys outside the shared checkout. Keep the password hash at its existing
    protected location outside the repository and Nix Store. Document separate
    backups for local host files, which shared Git history does not protect.
  - Support updating the complete declaratively managed system with
    `sudo nix flake update` in `/etc/nixos` followed by
    `sudo nixos-rebuild switch` (automatic local Flake and hostname selection).
    Document an explicit `--flake path:/etc/nixos#default` for hostname changes
    and explicit `path:` when Git filtering would otherwise omit host files.
    This normally fetches the project from GitHub; no Git
    pull in the fallback checkout is required. Avoid manual copying of project
    files and make the selected source explicit.
  - Document and validate the administrator-controlled local fallback: update
    `/etc/nixos/my-os-setup` with `git pull --ff-only` when a configured remote
    is reachable, then update the local System Flake lock with
    `nix flake update --override-input my-os-setup path:./my-os-setup` from
    `/etc/nixos`. Validate the exact CLI and whether the rebuild also needs the
    override. Explain persistence of the source override and how to return to
    the default GitHub input. Allow remote URL changes and additional remotes;
    a pull from GitHub cannot fetch new revisions while GitHub is unavailable.
    The bundled checkout must also support using its existing revision offline
    without pulling or updating unrelated network inputs.
  - Ensure ignored/untracked host files are included in evaluation, using an
    explicit `path:` Flake or a validated alternative. Never fall back silently
    to reference hardware/user settings during an installed-system rebuild.
  - Implement and test local project inclusion and lock handling: the local
    System Flake defines its system dependencies and `/etc/nixos/flake.lock`
    controls their versions. A full local `nix flake update` updates these
    dependencies and the selected project input, not just the project input.
    The shared checkout's `flake.lock` remains unchanged and serves ISO builds
    and project tests; installed systems may intentionally use newer dependency
    versions than the tested ISO. Do not force installed systems to follow the
    project's pinned package versions or assume `nixos-rebuild` performs updates.
    Have the local system composition explicitly provide packages and module
    arguments needed by AI/Gufo; importing a profile alone must not rely on
    implicit wiring from the project Flake. For AI and Full only, have Calamares
    generate `inputs.gufo.url = "github:gufo-org/gufo"` in the local
    System Flake as a normal Flake input (not `flake = false`) and wire its
    release package into the AI modules. Omit the Gufo input for other profiles.
    Do not pin a release tag in the installed system's input URL: an explicit
    `nix flake update` should advance Gufo to the current default-branch commit,
    which is not necessarily a stable release. Keep the exact commit locked in
    the local `flake.lock`; ordinary rebuilds must not update it. Preserve the
    ISO's tested Gufo revision in the initial offline lock. Validate that shared modules and
    AI/Gufo integration use the intended local dependencies. Define updates for
    managed model payloads separately; do not
    imply that `git pull` alone updates external mutable data.
  - Retain the installed project's sources and required Flake inputs against
    garbage collection so normal rebuilds with the existing lock do not depend
    on GitHub availability. Initialize the local lock to the ISO's project and
    dependency state without contacting GitHub during installation. Distinguish
    offline source availability from availability of newly required packages.
  - Validate migration, project update, SSH access after rebuild/reboot, local
    configuration preservation, GitHub/local source switching, offline rebuilds
    and rollback. Local host settings must remain effective and unchanged across
    pulls, Flake updates and rebuilds. Update `migration.md` and the
    administration documentation to describe the supported workflow.

### 13. Verified fetches

- [ ] Evaluate Nix's experimental `verified-fetches` support for authenticated
  Git source updates. Check availability in the project's supported Nix versions,
  exact input/fetcher configuration, supported signature formats and independently
  provisioned trusted public keys. Do not assume ordinary `github:` inputs verify
  Git signatures; determine whether verified fetching requires a Git input URL.
- [ ] Prototype signed project commits and enforced verification for the shared
  setup source, including its non-Flake input, local checkout overrides and
  ISO-provisioned offline sources. Reject unsigned or untrusted updates without
  silently bypassing verification; test key rotation and recovery behavior.
- [ ] Assess applicability to Gufo if independently trusted developer signatures
  become available. Document the limits: source authentication is not a guarantee
  of harmless code, and GitHub-generated signatures, lock hashes and binary-cache
  signatures provide different assurances. Update the supported update workflow
  only after verifying the behavior with the actual Nix version.

### 12. Gufo updates

- [ ] Validate Gufo updates for AI and Full through the untagged installed-system
  input and explicit `nix flake update`. Document that this follows the default
  branch rather than selecting stable releases. Evaluate additional automation
  separately and define whether it proposes, locks, builds or activates an
  update; do not silently activate untested code.
  Preserve offline rebuilds, reproducible locked versions and recovery to the
  previous working version.
- [ ] Verify updates where possible: investigate developer-signed releases or
  tags and independently provisioned trusted keys. Distinguish developer
  signatures from GitHub-generated commit signatures, content hashes and Cachix
  package signatures. Do not treat these as equivalent assurances or claim
  protection against a compromised release pipeline. If independent developer
  verification is unavailable, document the remaining trust assumptions and
  choose an explicit fallback policy rather than silently weakening checks.
- [ ] Test Gufo compatibility with the shared AI modules and managed model
  payloads before activation, including failed verification/build handling and
  rollback. Keep the initial offline lock at the ISO's tested Gufo revision while
  allowing later explicit updates independently of the project's ISO lock.

### 3. Release version tags

- [ ] Introduce joint releases of the Flake and its Base/Desktop/Gaming/AI modules using Git tags (for example `v0.1.0`); optionally use the same explicit release version in ISO filenames. Do not derive a build date automatically or change `system.stateVersion` for project versioning.

### 4. SSH provisioning

- [ ] Define supported SSH diagnostics access for installed systems as well as
  live media. The black-screen investigation required repeated manual daemon,
  account and firewall setup; provide declarative opt-in access with public-key
  authentication instead. Decide installed-system and live-installer behavior
  separately before implementation.

- [ ] Verify key-gated live SSH and optional installed-system SSH in Calamares.
  Use build-supplied public keys through the `ssh-keys` Flake input; verify
  key login, rejection of password/root login, offline installation with SSH
  enabled, reboot persistence, and the disabled target selection.

- [ ] Validate the documented `--override-input ssh-keys` build workflow with
  OpenPGP-exported public keys. Target keys are used only on explicit installer
  opt-in; no personal or private keys are auto-discovered on the build host.

### 5. TUI installer

- [ ] Provide general, installation-UI-independent hooks for post-installation
  operations such as preserving the initial system generation with a GC root.
  Support Calamares, manual `nixos-install` and a future TUI installer through
  the same mechanism. Evaluate native NixOS integration points before adding
  wrappers; define installation versus update semantics, target-system context,
  ordering, failure propagation and retry/reinstallation behavior. Validate each
  supported entry point. The current Calamares call is an interim integration,
  not the final architecture.

- [ ] Find and validate a suitable TUI installer for server provisioning over SSH, deploying this project's Flake with user-selected identity and disk settings. Check target-disk confirmation and keep target modules independent of the installation UI. Reassess existing Flake support in candidates such as nixos-wizard; the previous evaluation is recorded in [ADR 0001](docs/decisions/0001-installation-interface.md).

### 6. UKI boot

- [x] Implement direct UKI boot through the external bootloader hook, without
  systemd-boot/GRUB. Completed 2026-11-27: fresh Desktop VM installation,
  default NixOS boot, update and all three stable selections confirmed.
  Identical rebuild preserved entry numbers and BootOrder; the user also
  confirmed stable entry numbers across a subsequent real update, GC survival
  with the final stable files, external-hook offline rebuild and local Git fallback.
  See [UKI evidence and remaining coverage](docs/issues/solved/2026-11-27_direct-uki-boot.md).
  New installs use three fixed UKI filenames; no growing generation-file cache
  or additional cleanup infrastructure is needed.
- [x] Integrate graphical LUKS password entry through native NixOS Plymouth
  in the initrd. Completed 2026-11-27: installed profiles use the built-in
  `spinner` theme; local configuration can select custom theme packages.
  Profile checks, UKI hook builds and the Desktop initrd build passed.
  Encrypted VirtIO GPU VM confirmed graphical unlock, spinner and clean login
  handover without Escape or text flash. See the
  [resolved Plymouth issue](docs/issues/solved/2026-11-27_plymouth-boot.md)
  for the fix and validation limits.
  Plymouth can be used independently of direct UKI boot. No automatic LUKS
  unlocking; Secure Boot signing is a separate task.

### 7. SBOMs

- [ ] Make each variant's software inventory understandable and externally inspectable: provide separate SBOM build outputs for the target system and live ISO. Evaluate `sbomnix` with CycloneDX/SPDX output; distinguish live installer tools from target software. Record provenance, licenses and checksums of optional model weights using `modules/generative-ai/models.lock.json`. Document inventory and license-data completeness and limitations; an SBOM is not proof of security.

### 8. Alternative model sources

- [ ] Obtain model files independently of Hugging Face: let users supply files from a local directory or alternative web sources. Treat download locations as replaceable hints, not model identity; accept files based on the pinned manifest's expected contents and checksums, regardless of origin. Preserve the required file set and target layout, verify integrity before bundling or using files, and reject missing or mismatched files. Integrity verification does not replace trust in the reference manifest.

### 9. Favorite programs

- [ ] Assemble a workstation for its tasks without maintaining a separate ISO for every combination. Derive further composable modules from the previous Manjaro setup:
  - Development: Git with lazygit/tig/delta, editors, language servers, Meld, Zeal and HTTP/data tools; prefer `nix develop` for project-specific compilers and SDKs.
  - Virtualization: QEMU, libvirt and virt-manager with their required services and permissions.
  - Media: mpv, Audacity, HandBrake, video editing, yt-dlp and metadata tools.
  - Documents: e-book/PDF/comic readers and OCR with German and English language data.
  - Security tools: GnuPG, pass, OpenPGP smart-card and certificate tools; do not include personal keys or secrets in the repository.
  - Desktop utilities: file search, calculator, GPXSee and practical file-management tools.
  - Keep tool installation and preferred configuration together by topic, for example under `modules/git/`: `system.nix` installs Git/tig/lazygit/delta system-wide, while `home.nix` manages user configuration and aliases with Home Manager. Coordinate responsibilities and package versions for programs automatically installed by Home Manager. Do not blindly carry XFCE/X11-specific solutions over to KDE/Wayland; keep hardware workarounds with the respective PC.
  - Retain existing variants as presets; evaluate installer module selection later. Consider Desktop + Development + Virtualization as a workstation with optional Gaming and AI.

### 10. Manual partitioning

- [ ] Audit Calamares settings and native UI options currently hidden or disabled by our configuration. Identify which should be exposed to users and document why any remain unavailable.
- [ ] Implement and validate safe manual partitioning, including LUKS layouts, before exposing it in Calamares. The pinned Nixpkgs package includes `dont-allow-manual-luks.patch`; review supported native settings and target hardware-configuration integration before changing it. Keep manual partitioning disabled until verified; automatic whole-drive LUKS2 installation remains supported.

### 11. Time synchronization

- [ ] Configure and verify automatic time synchronization in live media and installed systems. Evaluate using NTP servers supplied by DHCP, with a documented fallback when DHCP supplies none; check integration with NetworkManager and the chosen time-sync service.

### Additional work: reusable libvirt images

- [ ] Provide NixOS variants directly as reusable libvirt base images: generate additional QCOW2 Flake outputs from the same target modules, for example with `nixos-generators`. Place the implementation under `modules/virtualization/`; configure boot mode, virtual hardware and initial access. Keep individual identity and secrets out of base images; evaluate cloud-init for first-boot configuration. Image/target-system tests do not replace ISO/Calamares installation evidence.

## Completed

- [x] 2026-11-27: Validate the new Desktop installed-system update workflow in the user's QEMU/KVM VM: offline short rebuild, clean bundled Git checkout with branch/upstream/remote, targeted local source override and reboot, online update to project commit `e42bf9186e4d89659a78783d22e7550690fdfe15`, rebuild/reboot, rollback/reboot and reactivation/reboot. The installed lock confirms the non-Flake GitHub project input; Nixpkgs remained at the ISO revision. No lock backup was used. See [repository-update evidence](docs/issues/2026-11-25_installed-system-repository-updates.md). This does not validate migration, SSH, AI/Full updates or Bosgame hardware.

- [x] 2026-11-26: Verify the [SPICE autostart workaround](docs/issues/2026-11-26_spice-session-autostart.md) in the rebuilt Desktop live ISO; both agents run without manual startup. The underlying issue remains open with status `workaround`.

- [x] 2026-11-26: Complete the real VM failure checks in [the installer-diagnostics issue](docs/issues/solved/2026-11-25_installer-failure-diagnostics.md), confirmed by the user.
