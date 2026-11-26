---
status: open
---

# Desktop installation requests unavailable build dependencies offline

## Observation

Installation of the Desktop ISO in the QXL/SPICE VM failed during system
installation on 2026-11-26. Calamares reported subprocess exit code 1.
The journal recorded the `nixos-install` invocation, but not its original
error output. No Calamares log file was found in the inspected locations.

The target disk had already been partitioned. The generated configuration
remained available under `/tmp/calamares-root-i49svp1a/etc/nixos`, with
target hostname `test-standardpc`.

## Reproduction and evidence

A direct build of the generated configuration reproduced a failure:

```bash
sudo nix build \
  /tmp/calamares-root-i49svp1a/etc/nixos#nixosConfigurations.test-standardpc.config.system.build.toplevel \
  --no-link --no-update-lock-file \
  --option build-dir /nix/var/nix/builds
```

Nix attempted source downloads for bzip2, gawk and GCC. Downloads failed
with `Could not resolve host` for `sourceware.org` and `ftpmirror.gnu.org`.
Subsequent dependency failures included the bootstrap toolchain,
`libredirect`, `nftables-rules`, and the target system.

Inspection of the pinned NixOS nftables module confirmed that its generated
ruleset's build-time check uses `buildPackages.libredirect`,
`buildPackages.lklWithFirewall.lib`, and `buildPackages.nftables`.
The prepared offline dependencies contained nftables, but neither
libredirect nor the LKL library.

No user manually added a firewall rule. NixOS generated rules as part of
system configuration. Why the generated rules require a different output
from the prebuilt seed remains unverified.

The direct build proves an offline dependency gap. The original installer
failure is consistent with it, but its missing output prevents independently
confirming that it failed for exactly the same reason.

## Changes implemented

- `7d9b37a`: add finished nftables validation tools to `offlineTools`.
- `a9b410a`: save streamed installation diagnostics to a private mode-0600
  temporary log, flush output as it arrives, and show a direct `less`
  command in the failure dialog. Secret-input commands remain excluded.
- Nix evaluation confirms that libredirect and LKL are now included in the
  explicit offline dependencies. All 38 adapter tests passed.

These changes address the observed dependency gap and diagnostic failure,
not a general guarantee for arbitrary offline configuration rebuilds.

## Next verification

- Build and boot the updated Desktop ISO.
- Repeat installation without network access and confirm completion.
- If installation fails, verify that the dialog identifies an existing log
  containing the original subprocess diagnostics.
- Determine which generated configuration change invalidates the seed's
  prebuilt nftables rules; do not assume a manually added rule.
- Close this issue only after the offline installation countercheck passes.

Do not reformat the failed target merely to inspect diagnostics. Temporary
logs and generated configuration should be preserved before rebooting.
