# Preparation

Status: The user confirmed the new Full ISO's GUI startup, model selection, live logging, model-copy progress, new model directory, separate-job behavior, boot without the ISO, Steam/Gufo and online update followed by reboot. Model integrity is accepted based on pinned download checksums during the ISO build and successful copying; no additional target-file checksum pass is required. Evidence covers this VM configuration, not every variant or arbitrary hardware.

## Further preparation

Contents:

1. [Full ISO verification on real hardware](#1-full-iso-verification)
2. [Release version tags](#2-release-version-tags)
3. [TUI installer](#3-tui-installer)
4. [SBOM outputs](#4-sboms)
5. [Alternative model sources](#5-alternative-model-sources)
6. [Favorite programs and configuration](#6-favorite-programs)
7. [Manual partitioning](#7-manual-partitioning)
8. [Optional Gufo update automation](#8-optional-gufo-update-automation)
9. [Verified Git source fetching](#9-verified-fetches)

Reusable libvirt images remain additional work after these priorities.

### 1. Full ISO verification

- [ ] Verify the Full ISO on the Bosgame M5: install without network access, verify boot and deployed programs, and test Bluetooth and compressed-only firmware usability during offline installation. Complete real-hardware inference verification in [the Gufo backend issue](docs/issues/2026-11-25_gufo-hardware-backend-validation.md).

### 2. Release version tags

- [ ] Introduce joint releases of the Flake and its Base/Desktop/Gaming/AI modules using Git tags (for example `v0.1.0`); optionally use the same explicit release version in ISO filenames. Do not derive a build date automatically or change `system.stateVersion` for project versioning.

### 3. TUI installer

- [ ] Provide general, installation-UI-independent hooks for post-installation
  operations such as preserving the initial system generation with a GC root.
  Support Calamares, manual `nixos-install` and a future TUI installer through
  the same mechanism. Evaluate native NixOS integration points before adding
  wrappers; define installation versus update semantics, target-system context,
  ordering, failure propagation and retry/reinstallation behavior. Validate each
  supported entry point. The current Calamares call is an interim integration,
  not the final architecture.

- [ ] Find and validate a suitable TUI installer for server provisioning over SSH, deploying this project's Flake with user-selected identity and disk settings. Check target-disk confirmation and keep target modules independent of the installation UI. Reassess existing Flake support in candidates such as nixos-wizard; the previous evaluation is recorded in [ADR 0001](docs/decisions/0001-installation-interface.md).

### 4. SBOMs

- [ ] Make each variant's software inventory understandable and externally inspectable: provide separate SBOM build outputs for the target system and live ISO. Evaluate `sbomnix` with CycloneDX/SPDX output; distinguish live installer tools from target software. Record provenance, licenses and checksums of optional model weights using `modules/generative-ai/models.lock.json`. Document inventory and license-data completeness and limitations; an SBOM is not proof of security.

### 5. Alternative model sources

- [ ] Obtain model files independently of Hugging Face: let users supply files from a local directory or alternative web sources. Treat download locations as replaceable hints, not model identity; accept files based on the pinned manifest's expected contents and checksums, regardless of origin. Preserve the required file set and target layout, verify integrity before bundling or using files, and reject missing or mismatched files. Integrity verification does not replace trust in the reference manifest.

### 6. Favorite programs

- [ ] Assemble a workstation for its tasks without maintaining a separate ISO for every combination. Derive further composable modules from the previous Manjaro setup:
  - Development: Git with lazygit/tig/delta, editors, language servers, Meld, Zeal and HTTP/data tools; prefer `nix develop` for project-specific compilers and SDKs.
  - Virtualization: QEMU, libvirt and virt-manager with their required services and permissions.
  - Media: mpv, Audacity, HandBrake, video editing, yt-dlp and metadata tools.
  - Documents: e-book/PDF/comic readers and OCR with German and English language data.
  - Security tools: GnuPG, pass, OpenPGP smart-card and certificate tools; do not include personal keys or secrets in the repository.
  - Desktop utilities: file search, calculator, GPXSee and practical file-management tools.
  - Keep tool installation and preferred configuration together by topic, for example under `modules/git/`: `system.nix` installs Git/tig/lazygit/delta system-wide, while `home.nix` manages user configuration and aliases with Home Manager. Coordinate responsibilities and package versions for programs automatically installed by Home Manager. Do not blindly carry XFCE/X11-specific solutions over to KDE/Wayland; keep hardware workarounds with the respective PC.
  - Retain existing variants as presets; evaluate installer module selection later. Consider Desktop + Development + Virtualization as a workstation with optional Gaming and AI.

### 7. Manual partitioning

- [ ] Audit Calamares settings and native UI options currently hidden or disabled by our configuration. Identify which should be exposed to users and document why any remain unavailable.
- [ ] Implement and validate safe manual partitioning, including LUKS layouts, before exposing it in Calamares. The pinned Nixpkgs package includes `dont-allow-manual-luks.patch`; review supported native settings and target hardware-configuration integration before changing it. Keep manual partitioning disabled until verified; automatic whole-drive LUKS2 installation remains supported.

### 8. Optional Gufo update automation

- [x] Gufo operation on Bosgame M5 and AI/Full updates including Gufo are
  confirmed by the user. No further implementation is needed for manual updates.
  Explicit Flake updates follow the untagged default branch, not stable releases.
- [ ] Optionally evaluate automation beyond manual `nix flake update` and
  `nixos-rebuild switch`. Define whether it proposes, locks, builds or activates
  an update; do not silently activate untested code.
  Preserve offline rebuilds, reproducible locked versions and recovery to the
  previous working version.
- [ ] If automation is implemented, test its failed-build handling and recovery
  before enabling it. These are acceptance tests for the optional automation,
  not outstanding validation of the working manual update workflow.
  Source-signature verification is a separate optional investigation below.

### 9. Verified fetches

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

### Additional work: reusable libvirt images

- [ ] Provide NixOS variants directly as reusable libvirt base images: generate additional QCOW2 Flake outputs from the same target modules, for example with `nixos-generators`. Place the implementation under `modules/virtualization/`; configure boot mode, virtual hardware and initial access. Keep individual identity and secrets out of base images; evaluate cloud-init for first-boot configuration. Image/target-system tests do not replace ISO/Calamares installation evidence.
