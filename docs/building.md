# Building and reusing the configuration

[Project overview and installation](../README.md).

## Requirements and checks

Use Linux x86_64 with a working Nix installation/store and `nix-command`/`flakes` enabled. If necessary, prefix commands
with `nix --extra-experimental-features 'nix-command flakes' …`; the Flake cannot enable features for its invoking Nix.

Use the committed lock for existing releases. Run `nix flake lock` when initially creating a lock; archive it with the
configuration. Do not update dependencies just to repeat a build.

```bash
nix fmt
nix build .#checks.x86_64-linux.installer-tests
nix build .#checks.x86_64-linux.profile-tests
nix build .#checks.x86_64-linux.reusable-module-tests
```

Focused tests do not prove a complete installation or boot.
When verifying offline installation, boot a finished ISO in a UEFI VM **without a network adapter**, choose identity and
language different from the reference, then test installation, LUKS unlock, login and the selected applications after
removing the ISO. This describes the evidence needed for an offline claim, not additional mandatory regression builds.
See [validation policy](decisions/0010-validation-and-evidence.md) and
[recorded limitations](issues/solved/2026-11-25_offline-installation.md).

Installation ISOs need the build revision as a separate Git folder, including `.git`.
Commit intended changes and build from a named branch. Create a clean, independent local clone:

```bash
repository_dir=$(mktemp -d /tmp/opencode/iso-repository.XXXXXX)
git clone --no-hardlinks --single-branch --branch "$(git branch --show-current)" . "$repository_dir"
nix build .#iso-desktop --out-link result-desktop \
  --override-input repository "path:$repository_dir" --no-write-lock-file
```

After the build, the temporary clone can be removed. No project lock is changed. Always create the clone from the
same clean commit being built; the clone does not include uncommitted changes. Unpushed commits are supported; the initial
offline source is the exact build revision. Commit intended changes first and keep unrelated untracked files outside
the checkout. Direct ISO outputs reject the default build-only placeholder input. Focused checks do not need a Git folder.
The folder includes history: never commit secrets, including in earlier revisions. Do not supply a personal checkout
with credential-bearing Git configuration, hooks or unrelated files; use the fresh clone above.

## Build-supplied SSH access keys

The live installer runs SSH on TCP port 22 only when public keys are supplied.
Empty files and comment-only files leave the service disabled. Password, keyboard-interactive
and root login are disabled. Supply public keys explicitly through the `ssh-keys`
Flake input; no personal keys are read from the build host automatically.

Create `local/ssh-keys/authorized_keys` in this checkout, with one public SSH key
per line. The `/local/` directory is Git-ignored and is not committed. For two
existing public SSH keys:

```bash
mkdir -p local/ssh-keys
cat ~/.ssh/key1.pub ~/.ssh/key2.pub > local/ssh-keys/authorized_keys
nix build .#iso-desktop --out-link result-desktop \
  --override-input repository "path:$repository_dir" \
  --override-input ssh-keys "path:$PWD/local/ssh-keys" \
  --no-write-lock-file
```

Use the same override for other ISO variants. Never place private keys in that
directory: the input and public-key file become part of the ISO/Nix Store.
For an OpenPGP authentication key, export its public SSH key with
`gpg --export-ssh-key <KEY-ID>` and add it as a line in `authorized_keys`.
The explicit `path:` input includes the keys despite the Git ignore rule.
The default input contains no keys; live SSH remains disabled.
Rebuilding without the override does not retain previously supplied
keys. Keep the public-key input directory to reproduce personalized images.

Connect to live media as `nixos`: `ssh nixos@<guest-ip>`. In Calamares, opt in to
**SSH Access** to enable SSH on the installed system. The supplied keys authorize
the newly created user, not root. Without that selection, target SSH remains
disabled. The installed key file is retained under `/etc/nixos/ssh-authorized-keys`
and can be edited explicitly before a rebuild.

Initial SSH access in live media also grants the live user's existing sudo
privileges. Only authorize trusted keys. Server host keys are generated at boot,
not shared across images. Find the address with `ip -br addr` locally; host-side
libvirt DHCP lease discovery is another option.

## Outputs

Names below are for `x86_64-linux`; `<profile>` is `base`, `desktop`, `gaming`, `ai` or `full`.

| Flake output                                      | Meaning                                             |
| ------------------------------------------------- | --------------------------------------------------- |
| `packages.x86_64-linux.iso-<profile>`               | Selected profile's live/install ISO                 |
| `packages.x86_64-linux.iso`, `default`              | Full ISO aliases                                    |
| `nixosConfigurations.<profile>`                   | Target system, not the live desktop                 |
| `nixosConfigurations.installer-<profile>`          | Live environment                                    |
| `nixosConfigurations.installer`                   | Full live alias                                     |
| `packages.x86_64-linux.offline-system`              | Full reference system with LUKS initrd components    |
| `packages.x86_64-linux.offline-source`              | Full archived setup and selected local input sources |
| `packages.x86_64-linux.models`                     | Full pinned model payload                           |
| `packages.x86_64-linux.calamares-extensions`        | Packaged installer extensions                       |
| `packages.x86_64-linux.calamares-welcome`           | Compiled early UEFI welcome extension                |

Installed systems additionally expose their configured hostname as a target for ordinary `nixos-rebuild switch`.
Artifacts appear through `result/`, not inside `build/`. Check actual image size before choosing/writing a USB drive.
AI/Full weights alone need roughly 115 GB; store/build requirements exceed image size. SquashFS compression is disabled.

## Gufo binary cache

Gufo follows its default branch through `github:gufo-org/gufo`; `flake.lock` fixes the exact build revision.
`nix flake update gufo` advances it without updating unrelated top-level inputs; this does not select stable releases.
Its toolchain inputs deliberately do not follow host Nixpkgs, preserving upstream
package/cache compatibility. The Gufo cache supplements the NixOS cache; without it, large local builds may be needed.
Cache use means trusting builds signed by its key, not proof that those builds are correct or every output is available.

On a NixOS build host, import the shared definition into a host system module, adjusting the checkout path:

```nix
{
  nix.settings = import /path/to/repository/modules/generative-ai/cache.nix;
}
```

Activate it with `sudo nixos-rebuild switch`. On other distributions, generate entries from the same definition:

```bash
nix eval --json --file modules/generative-ai/cache.nix \
  | jq -r 'to_entries[] | "\(.key) = \(.value | join(" "))"'
```

Merge them with existing `/etc/nix/nix.conf` entries. The definition adds the cache/key without replacing Nix defaults;
blanket `trusted-users` access and automatic Flake configuration approval are unnecessary. AI/Full target and live
systems configure the daemon cache themselves; the development and generated target Flakes have no root `nixConfig`.

**Never restart the daemon during a running ISO build.** After all Nix builds finish, on a non-NixOS daemon host:

```bash
sudo systemctl restart nix-daemon.service
nix build .#offline-system --dry-run
```

Inspect whether Gufo/ROCm outputs are scheduled for substitution. A configured cache can still lack locked outputs.

## Module reuse and build internals

Import `profiles/*.nix` or `modules/generative-ai/` by file path; no `nixosModules` registry is exported. Provide
your own users and filesystems; AI also requires the `gufoPackage` module argument. The independent AI module can run
headless. Base/Desktop/Gaming policy is in the profiles, not extra feature wrappers. Repository-only host/reference
selection is isolated in `modules/target-configuration.nix`.

`build/iso.nix` composes the image, `live.nix` configures the live environment, `offline.nix` prepares reference outputs
and assembly tools, and `offline-source.nix` archives inputs. Non-AI archives omit Gufo and its toolchain inputs.
Each ISO contains its own target package set, not necessarily the Full `offline-system` output.

The live desktop comes from Nixpkgs' `installation-cd-graphical-calamares-plasma6.nix`, importing
`installation-cd-graphical-calamares.nix`. Native KDE, Polkit, views and partition/mount jobs remain upstream.
A variant-independent Calamares package gets a separate configuration wrapper; settings changes do not recompile it.
The Python adapter handles preflight, local settings, hardware generation, password-hash setup, NixOS installation and
model copying. Native user jobs are omitted because users are configured declaratively. The C++ welcome extension adds
UEFI requirements through the official ViewStep interface, without replacing the welcome page or patching Calamares.

Installed locks initially use local store paths; online URLs remain in the local Flake. Target `system.extraDependencies`
keeps sources available after ISO removal and garbage collection. The generated AI/Full Flake supplies the ISO's Gufo
revision only for its original retained source to preserve
package identity. Shared locales and prepared outputs allow dynamic identity/UUID assembly without bundling the full
kernel/ROCm source/compiler graph. Normal installation permits both local and configured remote sources; offline
tests must block networking separately. `--no-root-passwd` suppresses a prompt; root remains locked.

Design rationale and comparison evidence live in [ADRs](decisions/README.md), especially
[offline preparation](decisions/0003-offline-system-preparation.md) and
[source trust](decisions/0007-package-source-trust.md).
Reproducibility covers pinned configuration/packages/model selection, not bit-identical SSD contents: disk UUIDs and
LUKS/password salts are newly generated. Steam updates independently; long-term repeatability requires available
downloads or your own package/model archive.
