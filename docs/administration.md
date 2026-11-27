# Administering an installed system

[Project overview](../README.md). Rebuilds do not partition or format disks, but may restart services; kernel changes
may need a reboot. Keep backups: neither rebuilds nor rollback restore all configuration files or personal data.
In examples using `#desktop`, substitute the installed or deliberately chosen profile.

## Time synchronization

Live media and installed systems use timesyncd exclusively with NTP addresses
received by NetworkManager through DHCPv4 or DHCPv6. There are no static
sources or fallbacks: without DHCP NTP information, no external synchronization
takes place. timesyncd does not provide a network server.
Check the actual synchronization with:

```bash
timedatectl status
timedatectl timesync-status
```

The DHCP dispatcher maintains per-interface drop-ins under
`/run/systemd/timesyncd.conf.d` and restarts timesyncd when sources change.
Libvirt's default NAT network
does not advertise NTP servers by default; advertising one via dnsmasq does not
itself start a time server. See [ADR-0013](decisions/0013-time-synchronization.md).

## Local settings and passwords

Installed Desktop and derived profiles use `time.timeZone = null;`: the
installer initializes the chosen timezone once, then KDE's Date & Time settings
or `sudo timedatectl set-timezone Europe/Berlin` can change it persistently.
Rebuilds do not reset that choice. Base/server installations retain their
declarative timezone; live media retain the existing UTC policy. No automatic
location detection is enabled. Timezone changes are independent of NTP.

The installed setup lives under `/etc/nixos` and generates:

- `configuration.nix`: editable hostname, user, language, local additions and the existing `system.stateVersion`.
- `hardware-configuration.nix`: hardware, filesystems and LUKS UUIDs, imported by the local configuration.
- `installation.json`: installation metadata, including the selected `variant`.
- `flake.nix` and `flake.lock`: local system composition and independently updatable dependency versions.
- `my-os-setup/`: root-managed Git checkout at the ISO revision, with a named branch and `origin` upstream.

The local Flake normally imports the selected profile from a non-Flake GitHub source input (`flake = false`),
without evaluating the project's Flake or using its ISO dependency graph. AI/Full additionally have a Gufo Flake input.
The checkout is an explicit fallback/development source, not a second automatically selected configuration.

Edit local settings rather than shared profiles:

```bash
sudo nano /etc/nixos/configuration.nix
sudo nixos-rebuild switch
```

The hostname alias follows `networking.hostName`; the explicit profile target remains available. Generated host files
are not secrets, but contain PC-specific data. If `/etc/nixos` becomes a Git checkout, explicitly include needed host
files or use a `path:/etc/nixos` Flake so ignored/untracked files are not filtered out.

The shipped `nixos-rebuild` automatically finds `/etc/nixos/flake.nix` and selects the running hostname.
When changing `networking.hostName`, use `sudo nixos-rebuild switch --flake path:/etc/nixos#default` once,
because the running hostname still has its old value. Explicit `path:` is also useful if `/etc/nixos` itself
becomes a Git repository; the fallback checkout in its subdirectory does not make the parent a Git repository.

The password hash stays outside the repository/store at `/var/lib/nixos-secrets/user-password.hash`. For persistent
password changes, replace that root-protected hash file; `users.mutableUsers = false` means plain `passwd` is not a
persistent change. Keep root login locked and never commit the hash or copy it into a development checkout.

## Update shared modules and dependencies online

An offline installation initially pins Flake inputs to retained local store paths. Original GitHub URLs stay in
`flake.nix`; `nix flake update` resolves them again and replaces local locks with network locks.

```bash
sudo cp /etc/nixos/flake.lock /etc/nixos/flake.before-update.lock
sudo nix flake update --flake path:/etc/nixos
sudo nixos-rebuild switch
```

This updates within configured branches/tags. Nixpkgs follows `nixos-unstable`, not necessarily every latest upstream
release. AI/Full already configure the Gufo cache/key in the daemon and need no extra Flake cache approval.
Shared project modules update along with these inputs; no checkout pull or file copying is needed. Local host files
and the checkout's project lock remain unchanged. Newer system dependencies than the ISO's tested versions are intentional.

Gufo uses `github:gufo-org/gufo` without a release tag. `nix flake update` selects the current default-branch commit,
not necessarily a stable release; ordinary rebuilds use the exact commit in `flake.lock`. Existing installations
whose `flake.nix` still specifies a Gufo release tag must remove that tag to adopt this update policy.
Review changed options/model requirements before activation. Cache signatures authenticate the cache publisher,
not the safety of new code. **Flake updates do not update the repository's model manifest or copied
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

## Local checkout fallback

New installations mark the bundled project commit with the local annotated tag
`nixos-install`. It records the installation-time tagger date and is not pushed
automatically. Inspect it with `git -C /etc/nixos/my-os-setup show nixos-install`.

Use the bundled checkout without GitHub, or pull it from a reachable remote after reviewing changes:

```bash
sudo git -C /etc/nixos/my-os-setup pull --ff-only
sudo cp /etc/nixos/flake.lock /etc/nixos/flake.before-update.lock
sudo nix flake update my-os-setup \
  --flake path:/etc/nixos \
  --override-input my-os-setup path:/etc/nixos/my-os-setup
sudo nixos-rebuild switch
```

Omit the pull and add `--offline` to the targeted update when using the existing checkout without network access.
Only the project source is updated by this command; unrelated dependency inputs remain locked. Use a full
`sudo nix flake update --flake path:/etc/nixos --override-input my-os-setup path:/etc/nixos/my-os-setup`
for intentional dependency updates too.
The override is recorded in the lock: a subsequent rebuild needs no override. After checkout edits or pulls,
repeat the targeted override update to refresh its content hash.

The input's original GitHub URL remains unchanged. To return to GitHub:

```bash
sudo nix flake update my-os-setup --flake path:/etc/nixos
sudo nixos-rebuild switch
```

An ordinary full update also returns to the configured GitHub source unless the override is supplied again.
Change `origin` or add another remote explicitly if needed; a GitHub pull cannot obtain new commits during a GitHub outage.
Keep local host files outside the checkout. Missing host configuration causes evaluation to fail, not reference fallback.

Flake sources are retained through the system generation's `system.extraDependencies`, including transitive inputs.
Keep the relevant system generation to protect those sources from garbage collection. Available sources do not imply
that arbitrary new packages can be built offline. Explicit `path:/etc/nixos` evaluation may copy the bundled checkout
and history to the store; do not store secrets anywhere in this tree.

Existing archive-based installations require migration or reinstallation; their old Flake does not acquire this layout
by updating dependency locks alone. See [the repository-update issue](issues/2026-11-25_installed-system-repository-updates.md).
