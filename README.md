# Modular NixOS installer

Build a reproducible NixOS USB image and install it through the graphical Calamares wizard, with optional Steam and
local AI inference through Gufo. Install the selected profile offline with user-chosen identity and disk settings.

> **Installation erases the entire selected drive, including Windows and all existing data.**
> No dual boot or manual partitioning. Back up your data and verify the target device before confirming.

## Choose a profile

| Profile | Installed system             | ISO output     | Free application packages |
| ------- | ---------------------------- | -------------- | ------------------------- |
| Base    | Console system               | `iso-base`     | ✅                        |
| Desktop | Base + KDE, audio, Firefox   | `iso-desktop`  | ✅                        |
| Gaming  | Desktop + Steam              | `iso-gaming`   | ❌ Steam                  |
| AI      | Desktop + Gufo               | `iso-ai`       | ✅                        |
| Full    | Gaming + Gufo                | `iso-full`     | ❌ Steam                  |

Every **live ISO** includes KDE and Calamares; the **installed Base system** does not include KDE or Firefox.
Only AI/Full images bundle the six pinned Qwen3.8-Flash-Next model files. Copying them is optional; Gufo stays installed
even without weights. Declining copying saves about 107 GiB on the target, not on the ISO or build host.

Unfree application permissions are limited to Steam in Gaming/Full. All profiles enable redistributable firmware;
model weights have separate licenses. This is not a complete license audit or a claim that every image is entirely free.

## Requirements and limits

- **Build host:** Linux x86_64 with working Nix and a Nix store; enable `nix-command` and `flakes`.
- **Target:** x86_64 with UEFI; disable Secure Boot. Minimum disk size: 32 GiB, or 256 GiB for AI/Full.
- **AI/Full storage:** weights alone total about 115 GB. A 256 GB USB drive is a reasonable starting point;
  check the actual ISO size. Building needs substantially more free Nix-store space than the final image.
- **GPU inference:** pinned Gufo v0.36.0 uses ROCm for AMD Strix Halo (`gfx1151`). Other GPUs need a suitable
  backend/build.
  Enough RAM/GPU memory is required; installing Gufo does not prove working inference.
- **Offline scope:** images include prepared systems, locked inputs and assembly tools, not every compiler/source
  dependency or arbitrary hardware driver. Later Steam login, game/client updates and new packages require Internet.

## Build the ISO

From the repository checkout, build the chosen profile ([build checks and outputs](docs/building.md)):

```bash
nix build .#iso-desktop
```

Find the image under `result/iso/`. `nix build .#iso` and the default package select **Full**, including the large model
payload. Use the committed `flake.lock` for repeatable builds; run `nix flake update` only for intentional dependency
updates. If experimental features are disabled, prefix Nix commands with
`nix --extra-experimental-features 'nix-command flakes' …`.

For AI/Full, the optional [Gufo binary cache](docs/building.md#gufo-binary-cache) can avoid large local ROCm builds.
Configure it on the build host **before** starting the build; never restart the daemon during a running build.

## Install

1. Write the ISO to the **correct USB drive**, for example with KDE ISO Image Writer. This erases that USB drive too.
2. Disable Secure Boot and boot the USB in **UEFI mode** (OVMF for VMs). The KDE live desktop logs in as `nixos`;
   no network is required for the intended offline installation. The live image provides no SSH access.
3. Open Calamares through autostart or the desktop shortcut. Choose language, time zone, keyboard, hostname, user
   and password. The ISO fixes the profile; there is no desktop-selection step. If a SPICE channel is detected,
   an optional guest-integration choice is offered; it stays disabled unless selected.
4. Select the **correct target SSD** and choose **Erase disk**. LUKS encryption is preselected but optional.
   No swap is supported.
5. For AI/Full, choose whether to copy the included Qwen weights (preselected). Carefully verify the target's model,
   size and device in the summary, then accept the final confirmation.
6. Wait for the **Finish page**, not merely 100% progress. NixOS installation and model copying are separate jobs.
   Reboot, remove the ISO, unlock LUKS if enabled, and log in (console for Base, KDE otherwise).

### Disk layout and security

- A 1 GiB unencrypted EFI partition and Btrfs for the remaining space, optionally inside LUKS2.
- Btrfs uses `compress=zstd` and `noatime`; no extra subvolumes, automatic snapshots, swap or hibernation setup.
- Kernel and initrd remain on the unencrypted EFI partition. Encryption does **not** prevent physical boot tampering.
  There is no stored LUKS key, automatic TPM unlock or Secure Boot signing.
- Root login is locked; the chosen user can use `sudo` with their password. The user password hash is stored outside
  the Nix store at `/var/lib/nixos-secrets/user-password.hash`. Persistent password changes require updating that file.

If installation fails, **do not repeat it just to retry model copying**: a normal reinstall erases the drive again.
Save logs before rebooting and follow [diagnosis and model-copy recovery](docs/troubleshooting.md).

## Use and maintain the installed system

Local settings live in `/etc/nixos/configuration.nix`, which imports generated hardware settings:

```bash
sudo nano /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

A rebuild does not repartition or erase your drive; it can restart services, and kernel changes may need a reboot.
It is not a substitute for backups. [Administration](docs/administration.md) covers dependency updates, rollback,
password changes and applying repository changes. **`nix flake update` updates dependencies, not this project's files.**

For AI/Full, see [Gufo usage and model management](docs/ai.md).
