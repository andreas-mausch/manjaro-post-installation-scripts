# Administering an installed system

[Project overview](../README.md). Rebuilds do not partition or format disks, but may restart services; kernel changes
may need a reboot. Keep backups: neither rebuilds nor rollback restore all configuration files or personal data.
In examples using `#desktop`, substitute the installed or deliberately chosen profile.

## Local settings and passwords

The installed setup lives under `/etc/nixos` and generates:

- `configuration.nix`: editable hostname, user, language, local additions and the existing `system.stateVersion`.
- `hardware-configuration.nix`: hardware, filesystems and LUKS UUIDs, imported by the local configuration.
- `installation.json`: installation metadata, including the selected `variant`.

Edit local settings rather than shared profiles:

```bash
sudo nano /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

The hostname alias follows `networking.hostName`; the explicit profile target remains available. Generated host files
are not secrets, but contain PC-specific data. If `/etc/nixos` becomes a Git checkout, explicitly include needed host
files or use a `path:/etc/nixos` Flake so ignored/untracked files are not filtered out.

The password hash stays outside the repository/store at `/var/lib/nixos-secrets/user-password.hash`. For persistent
password changes, replace that root-protected hash file; `users.mutableUsers = false` means plain `passwd` is not a
persistent change. Keep root login locked and never commit the hash or copy it into a development checkout.

## Update dependencies online

An offline installation initially pins Flake inputs to retained local store paths. Original GitHub URLs stay in
`flake.nix`; `nix flake update` resolves them again and replaces local locks with network locks. `flake.online.lock`
backs up the original network state but is not required for updating.

```bash
cd /etc/nixos
sudo cp flake.lock flake.before-update.lock
sudo nix flake update
sudo nixos-rebuild switch --flake path:/etc/nixos#desktop
```

This updates within configured branches/tags. Nixpkgs follows `nixos-unstable`, not necessarily every latest upstream
release. AI/Full already configure the Gufo cache/key in the daemon and need no extra Flake cache approval.

Gufo stays pinned to `github:gufo-org/gufo/v0.36.0`. To upgrade it, edit that tag before updating/rebuilding and
review changed options/model requirements. **Flake updates do not update the repository's model manifest or copied
weights.** New packages and updates may need downloads; offline initial installation does not imply offline updates.

If the build fails, the currently active system remains intact. Restore the previous lock if needed:

```bash
sudo cp /etc/nixos/flake.before-update.lock /etc/nixos/flake.lock
```

If problems appear after activation, return to the previous generation:

```bash
sudo nixos-rebuild switch --rollback
```

Rollback does not restore configuration files or locks; restore those from backups/Git separately.
VM update/reboot evidence is in [the offline investigation](issues/solved/2026-11-25_offline-installation.md).

## Apply changes from this repository

`nix flake update` updates dependencies, **not this project's module files**. `/etc/nixos` is an archived copy, not an
automatically maintained checkout. To apply repository changes without reinstalling, use your own checkout, for example
`~/coding/nixos-setup`.

> **The checkout must contain this exact PC's configuration, hardware settings and installation metadata.**
> Without them, evaluation falls back to reference disk/user settings. This checkout workflow is documented but has not
> been VM-validated; the future pinned-input workflow that avoids copying host data is not implemented.

Inspect any existing local files before copying; do not overwrite unrelated work:

```bash
cd ~/coding/nixos-setup
cp /etc/nixos/hardware-configuration.nix .
cp /etc/nixos/installation.json .
cp /etc/nixos/configuration.nix .
sudo nixos-rebuild switch --flake "path:$HOME/coding/nixos-setup#desktop"
```

Use `path:` explicitly: a Git Flake omits ignored/untracked files, including deliberately ignored host data. Keep
PC-specific files out of shared commits and leave the password hash on the target at its existing protected location.

For later project updates, review/account for local changes, run `git pull --ff-only`, then repeat the same rebuild.
Optionally update dependencies separately; retain a published release's lock for a repeatable build.
**Rebuilding from the checkout does not update `/etc/nixos`.** Keep using the same source, or an ordinary rebuild from
the older archive could reactivate old project files. Track this limitation in
[the repository-update issue](issues/2026-11-25_installed-system-repository-updates.md).
