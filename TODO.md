# Preparation

Status: The user confirmed the new Full ISO's GUI startup, model selection, live logging, model-copy progress, new model directory, separate-job behavior, boot without the ISO, Steam/Gufo and online update followed by reboot. Model integrity is accepted based on pinned download checksums during the ISO build and successful copying; no additional target-file checksum pass is required. Evidence covers this VM configuration, not every variant or arbitrary hardware.

## Further preparation

- [ ] Obtain model files independently of Hugging Face: let users supply files from a local directory or alternative web sources. Treat download locations as replaceable hints, not model identity; accept files based on the pinned manifest's expected contents and checksums, regardless of origin. Preserve the required file set and target layout, verify integrity before bundling or using files, and reject missing or mismatched files. Integrity verification does not replace trust in the reference manifest.

- [ ] Provide NixOS variants directly as reusable libvirt base images: generate additional QCOW2 Flake outputs from the same target modules, for example with `nixos-generators`. Place the implementation under `modules/virtualization/`; configure boot mode, virtual hardware and initial access. Keep individual identity and secrets out of base images; evaluate cloud-init for first-boot configuration. Image/target-system tests do not replace ISO/Calamares installation evidence.

- [ ] Make each variant's software inventory understandable and externally inspectable: provide separate SBOM build outputs for the target system and live ISO. Evaluate `sbomnix` with CycloneDX/SPDX output; distinguish live installer tools from target software. Record provenance, licenses and checksums of optional model weights using `modules/generative-ai/models.lock.json`. Document inventory and license-data completeness and limitations; an SBOM is not proof of security.

- [ ] Assemble a workstation for its tasks without maintaining a separate ISO for every combination. Derive further composable modules from the previous Manjaro setup:
  - Development: Git with lazygit/tig/delta, editors, language servers, Meld, Zeal and HTTP/data tools; prefer `nix develop` for project-specific compilers and SDKs.
  - Virtualization: QEMU, libvirt and virt-manager with their required services and permissions.
  - Media: mpv, Audacity, HandBrake, video editing, yt-dlp and metadata tools.
  - Documents: e-book/PDF/comic readers and OCR with German and English language data.
  - Security tools: GnuPG, pass, OpenPGP smart-card and certificate tools; do not include personal keys or secrets in the repository.
  - Desktop utilities: file search, calculator, GPXSee and practical file-management tools.
  - Keep tool installation and preferred configuration together by topic, for example under `modules/git/`: `system.nix` installs Git/tig/lazygit/delta system-wide, while `home.nix` manages user configuration and aliases with Home Manager. Coordinate responsibilities and package versions for programs automatically installed by Home Manager. Do not blindly carry XFCE/X11-specific solutions over to KDE/Wayland; keep hardware workarounds with the respective PC.
  - Retain existing variants as presets; evaluate installer module selection later. Consider Desktop + Development + Virtualization as a workstation with optional Gaming and AI.

- [ ] Update an installed PC from this repository without reinstalling or copying its hardware/user data into the development repository. Keep PC configuration under `/etc/nixos` and consume reusable setup modules as a pinned Flake input. Adjust the current relative hardware/identity imports; also support updates from a local checkout without `--impure`. Document and test the workflow.

- [ ] Introduce joint releases of the Flake and its Base/Desktop/Gaming/AI modules using Git tags (for example `v0.1.0`); optionally use the same explicit release version in ISO filenames. Do not derive a build date automatically or change `system.stateVersion` for project versioning.

- [ ] Evaluate a suitable TUI installer as an alternative to the graphical live environment later; keep target modules independent of the installation UI.

- [ ] Prepare direct UKI boot for the installed system: UEFI starts the Unified Kernel Image without systemd-boot/GRUB. Implement and test UKI generation, installation on the EFI partition, UEFI boot entries and safe updates with fallback/recovery for previous generations. Integrate graphical LUKS password entry through Plymouth in the initrd; test the theme, early GPU drivers and password/text fallback on target hardware. Plymouth can be used independently of direct UKI boot. No automatic LUKS unlocking; Secure Boot signing is a separate task.

- [ ] Test the new diagnostic phases, journal time filter and warning about an already partitioned target during a real VM installation failure; original output must include the first Nix error.

- [ ] Add swap support before release: `nixos-generate-config` detects only active swap partitions, not swap files; Calamares creates swap files in the fstab module, which is not executed here. Test target-device mapping and encrypted swap after reboot. Retain “no swap” until then.

- [ ] Test Gufo GPU inference and the model on suitable real hardware (not possible in a VM without GPU passthrough).
