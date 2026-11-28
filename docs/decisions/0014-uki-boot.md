---
status: accepted
date: 2026-11-28
deciders: [neonew]
supersedes: []
superseded-by: []
---

# 0014: UKI boot

## Context

The user explicitly requires direct UEFI boot of full Unified Kernel Images
(UKIs), without systemd-boot or GRUB as an intermediate boot manager. The
firmware menu must offer three stable selections: the current system, its
predecessor and the original installation system. The installation baseline
must survive updates and garbage collection until full reinstallation.

Direct boot was implemented and validated in a Desktop UEFI VM on 2026-11-27.
On 2026-11-28 the user explicitly reaffirmed that systemd-boot is unwanted and
that this requirement excludes Lanzaboote. This record documents the existing
architecture and that confirmed rationale; it does not claim a historical
technical evaluation of Lanzaboote that is not recorded elsewhere.

The user also confirmed on 2026-11-28 that accumulating NixOS generations were
the original motivation for choosing three stable roles: avoid a growing set of
boot selections while retaining Current, Previous and the installation baseline.
This records the user's decision rationale, not a claim that NixOS generations
necessarily grow without bound or cannot be limited using standard mechanisms.

## Decision

Boot full UKIs directly through UEFI firmware entries. Do not introduce
systemd-boot or GRUB. Use upstream `ukify` and systemd-stub to assemble the UKIs,
with the project's focused NixOS installation hook managing the three stable
firmware entries and the retained installation baseline.

Do not adopt Lanzaboote's standard NixOS integration: it installs and manages
systemd-boot, contrary to the explicit boot architecture requirement. This is
an architectural exclusion, not a finding that Lanzaboote is defective or
cannot support UKIs or initramfs secrets. Reusing individual Lanzaboote tools
would require separate evaluation and is not the same as adopting its standard
integration.

Using systemd-stub inside a UKI does not introduce systemd-boot: the stub is the
EFI entry point of the image, not a separate boot-menu application. Likewise,
the project's hook is host-side image and firmware-entry management, not a
newly implemented EFI bootloader.

Secure Boot remains disabled in the currently supported setup. Direct UKI boot
does not inherently prevent future image signing; Secure Boot is a separate
security decision, not the decisive reason for excluding Lanzaboote here.

## Consequences

- **Positive:** The firmware starts the selected image directly, with no
  additional boot manager. The three role names and installation baseline
  follow the explicitly requested recovery model.
- **Negative:** The project must maintain UKI deployment, firmware-entry
  management and recovery retention instead of delegating them to a standard
  systemd-boot integration. This additional maintenance cost is accepted to
  preserve the user's requirement.
- The three roles bound the project's boot selections and UKIs, not the stored
  NixOS profile generations. The current implementation does not automatically
  delete old generations; storage cleanup remains a separate policy.
- **Risks / neutral:** Firmware behavior varies between machines. Atomic image
  replacement does not make the complete three-image update transactional.
  Hardware, recovery and security validation remain separately scoped.
- Standard upstream tools and NixOS interfaces should still be reused wherever
  they fit. This decision does not authorize unnecessary custom infrastructure.

## Options considered

| Option                            | Verdict      | Reason                                           |
| --------------------------------- | ------------ | ------------------------------------------------ |
| Direct UEFI boot of full UKIs      | ✅ Selected  | Meets the explicit no-intermediate-manager policy |
| systemd-boot as UKI boot manager   | Rejected     | The user explicitly does not want systemd-boot    |
| Lanzaboote's NixOS integration     | Rejected     | Uses systemd-boot, violating the same requirement |

### Comparison with standard integrations

| Responsibility         | Current project integration              | systemd-boot / Lanzaboote integration     |
| ---------------------- | ---------------------------------------- | ---------------------------------------- |
| Boot selection         | Direct UEFI firmware entries per role    | systemd-boot discovers and presents UKIs  |
| Generation management  | Project hook keeps three stable roles    | Integration manages NixOS generations    |
| UKI assembly           | Project hook invokes upstream ukify      | Lanzaboote assembles boot artifacts       |
| Secure Boot signing    | Not enabled in the current setup         | Lanzaboote provides signing integration   |
| Installation baseline  | Permanently retained initial generation  | Our exact retention policy needs review  |
| Local network hardware | Target-local driver and firmware overlay | Our discovery requirement needs review   |

The standard integration can take over substantial deployment and generation
management, but introduces systemd-boot. It is therefore an architectural
alternative, not a drop-in replacement that preserves the selected boot path.
The exact Current/Previous/Installation policy and target-local network-driver
discovery are not established as equivalent features of the standard solution.

Lanzaboote's default stub can keep the kernel and initramfs separately on the
EFI partition, with integrity verification, rather than embedding both in one
full UKI. This also differs from our full-image requirement.

## References

- [Direct UKI boot implementation and VM evidence](../issues/solved/2026-11-27_direct-uki-boot.md).
- [UKI integration](../../modules/uki.nix) and [entry management](../../modules/uki/entries.py).
- [Validation and evidence policy](0010-validation-and-evidence.md).
- [Lanzaboote overview and stub design](https://github.com/nix-community/lanzaboote#stub).
- [Lanzaboote NixOS module](https://github.com/nix-community/lanzaboote/blob/master/nix/modules/lanzaboote.nix),
  inspected on 2026-11-28: the installation command supplies
  `--systemd-boot-loader-config` and its settings configure systemd-boot.
