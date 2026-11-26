# Preparation

Status: The user confirmed the new Full ISO's GUI startup, model selection, live logging, model-copy progress, new model directory, separate-job behavior, boot without the ISO, Steam/Gufo and online update followed by reboot. Model integrity is accepted based on pinned download checksums during the ISO build and successful copying; no additional target-file checksum pass is required. Evidence covers this VM configuration, not every variant or arbitrary hardware.

## Further preparation

Priority order:

SSH provisioning is the current first priority, ahead of hardware verification
and repository updates. Existing section numbers remain stable for links.

4. [Secure SSH provisioning access](#4-ssh-provisioning)
1. [Full ISO verification on real hardware](#1-full-iso-verification)
2. [Repository-update workflow implementation and testing](#2-repository-updates)
3. [Release version tags](#3-release-version-tags)
5. [TUI installer](#5-tui-installer)
6. [UKI boot](#6-uki-boot)
7. [SBOM outputs](#7-sboms)
8. [Alternative model sources](#8-alternative-model-sources)
9. [Favorite programs and configuration](#9-favorite-programs)
10. [Manual partitioning](#10-manual-partitioning)
11. [Time synchronization](#11-time-synchronization)

Reusable libvirt images remain additional work after these priorities.

### 1. Full ISO verification

- [ ] Verify the Full ISO on the Bosgame M5: install without network access, verify boot and deployed programs, and test Bluetooth and compressed-only firmware usability during offline installation. Complete real-hardware inference verification in [the Gufo backend issue](docs/issues/2026-11-25_gufo-hardware-backend-validation.md).

### 2. Repository updates

- [ ] Implement and validate the host-independent repository-update workflow described in [the repository-update issue](docs/issues/2026-11-25_installed-system-repository-updates.md).

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

- [ ] Find and validate a suitable TUI installer for server provisioning over SSH, deploying this project's Flake with user-selected identity and disk settings. Check target-disk confirmation and keep target modules independent of the installation UI. Reassess existing Flake support in candidates such as nixos-wizard; the previous evaluation is recorded in [ADR 0001](docs/decisions/0001-installation-interface.md).

### 6. UKI boot

- [ ] Prepare direct UKI boot for the installed system: UEFI starts the Unified Kernel Image without systemd-boot/GRUB. Implement and test UKI generation, installation on the EFI partition, UEFI boot entries and safe updates with fallback/recovery for previous generations. Integrate graphical LUKS password entry through Plymouth in the initrd; test the theme, early GPU drivers and password/text fallback on target hardware. Plymouth can be used independently of direct UKI boot. No automatic LUKS unlocking; Secure Boot signing is a separate task.

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

- [x] 2026-11-26: Verify the [SPICE autostart workaround](docs/issues/2026-11-26_spice-session-autostart.md) in the rebuilt Desktop live ISO; both agents run without manual startup. The underlying issue remains open with status `workaround`.

- [x] 2026-11-26: Complete the real VM failure checks in [the installer-diagnostics issue](docs/issues/solved/2026-11-25_installer-failure-diagnostics.md), confirmed by the user.
