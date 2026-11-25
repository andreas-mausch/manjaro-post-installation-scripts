# Preparation

Status: The earlier offline Calamares test in the existing UEFI VM is complete: installation without manual flags, subsequent boot, KDE and Gufo, online update, rebuild and reboot succeeded. The user also confirmed the new Full ISO's GUI startup, model selection, live logging, model-copy progress, new model directory and separate-job behavior. A complete new offline installation/update cycle and the remaining variants are not yet confirmed.

## Next: modular ISO variants

- [ ] Confirm the new Base/Desktop/AI/Gaming/Full variants in offline installation runs; local module, installer and archive tests do not replace installation evidence.

- [ ] Complete offline validation of the generalized configuration in the existing VM using the new ISO; repeat boot without the ISO and online update followed by reboot. The new Full ISO's GUI, live logging and separate installation/model jobs are already user-confirmed.

## Further preparation

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

- [ ] Test variant-specific Calamares configuration paths in the live GUI for Base/Desktop/Gaming without model selection and AI with model selection; Full is confirmed.

- [ ] Evaluate a suitable TUI installer as an alternative to the graphical live environment later; keep target modules independent of the installation UI.

- [ ] Prepare direct UKI boot for the installed system: UEFI starts the Unified Kernel Image without systemd-boot/GRUB. Implement and test UKI generation, installation on the EFI partition, UEFI boot entries and safe updates with fallback/recovery for previous generations. Integrate graphical LUKS password entry through Plymouth in the initrd; test the theme, early GPU drivers and password/text fallback on target hardware. Plymouth can be used independently of direct UKI boot. No automatic LUKS unlocking; Secure Boot signing is a separate task.

- [ ] Add a reproducible isolated offline system-build/assembly test to the repository and require it before every ISO release: separate live/target stores, ISO contents only, no network and a fresh target store per variant; with/without LUKS and differing user/hardware configuration. No root tests on the host or additional test VM; obtain actual installation/boot evidence using the ISO in the existing VM. Improve automatic tool derivation rather than maintaining only a manual list long-term.

- [ ] Test the new diagnostic phases, journal time filter and warning about an already partitioned target during a real VM installation failure; original output must include the first Nix error.

- [ ] Add swap support before release: `nixos-generate-config` detects only active swap partitions, not swap files; Calamares creates swap files in the fstab module, which is not executed here. Test target-device mapping and encrypted swap after reboot. Retain “no swap” until then.

- [ ] Test further installation cases: unencrypted targets and empty or mismatched LUKS passphrases; Calamares must reject invalid passphrases before installation. The encrypted baseline run passed.

- [ ] Test the Calamares welcome-page UEFI requirement in BIOS and UEFI VMs; BIOS boot must block “Next” before partitioning.

- [ ] Fully test further offline variants with a different language and both model-copy options; compare all six copied model files with the manifest. The successful baseline does not fully cover these variants or file verification.
- [ ] Test Gufo GPU inference and the model on suitable real hardware (not possible in a VM without GPU passthrough).
