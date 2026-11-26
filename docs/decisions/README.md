# Decision Records

Architecture Decision Records (ADRs) for this repository, in
[Nygard style](https://thinkrelevance.com/blog/2011/11/15/documenting-architecture-decisions).

Record significant decisions about system composition, installation, build
structure, integrations, security boundaries and quality policies, not routine
dependency updates or individual bug fixes. Usage instructions belong in the
root [README](../../README.md); diagnosis and verification belong in
[issue records](../issues/). Planned work remains in [TODO.md](../../TODO.md).

## Index

| #    | Title                                                                          | Decision                                             | Status         | Date       | Supersedes |
| ---- | ------------------------------------------------------------------------------ | ---------------------------------------------------- | -------------- | ---------- | ---------- |
| 0001 | [Installation interface](0001-installation-interface.md)                       | Native Calamares with focused Flake adapter           | ✅ `accepted` | 2026-11-25 | none       |
| 0002 | [System composition](0002-system-composition.md)                               | Composed profiles, independent modules, file imports  | ✅ `accepted` | 2026-11-26 | none       |
| 0003 | [Offline system preparation](0003-offline-system-preparation.md)               | Prepared outputs, direct tools and archived inputs    | ✅ `accepted` | 2026-11-25 | none       |
| 0004 | [Model deployment](0004-model-deployment.md)                                   | Pinned ISO weights with optional separate copying     | ✅ `accepted` | 2026-11-25 | none       |
| 0005 | [Hardware and inference boundaries](0005-hardware-and-inference-boundaries.md) | Generated hardware settings, manual local inference   | ✅ `accepted` | 2026-11-25 | none       |
| 0006 | [Host configuration and secrets](0006-host-configuration-and-secrets.md)       | Editable local Nix settings, external password hash   | ✅ `accepted` | 2026-11-25 | none       |
| 0007 | [Package source trust](0007-package-source-trust.md)                           | Source-scoped ISO trust, normal signature checks      | ✅ `accepted` | 2026-11-25 | none       |
| 0008 | [Installer extension boundaries](0008-installer-extension-boundaries.md)       | Shared package, public APIs, minimal local fixes      | ✅ `accepted` | 2026-11-26 | none       |
| 0009 | [Package license policy](0009-package-license-policy.md)                       | Scoped Steam exception, separate firmware policy      | ✅ `accepted` | 2026-11-25 | none       |
| 0010 | [Validation and evidence](0010-validation-and-evidence.md)                     | Scoped checks with explicit unverified coverage       | ✅ `accepted` | 2026-11-25 | none       |

| 0011 | [Wi-Fi backend](0011-wifi-backend.md)                                           | NetworkManager with iwd, no supplicant service         | ✅ `accepted` | 2026-11-26 | none       |
| 0012 | [Firewall backend](0012-firewall-backend.md)                                   | NixOS firewall with nftables, host-local port policy   | ✅ `accepted` | 2026-11-26 | none       |

The initial records were reconstructed on 2026-11-26 from current files and
Git history. Dates identify the implementation or explicit policy evidence
described in each record, not an invented approval date. Empty `deciders`
means the inspected evidence did not explicitly identify the final approver.
`accepted` describes a decision currently in effect, not complete verification
of every implementation path. Earlier implementations without ADRs do not
receive fabricated supersession references.

## Status values

| Status                   | Icon        | Meaning                                                          |
| ------------------------ | ----------- | ---------------------------------------------------------------- |
| `proposed`               | 🕐          | Researched/recommended, not agreed; the old decision still applies |
| `accepted`               | ✅          | Decision in effect                                               |
| `rejected`               | 🚫          | Proposed but decided against; never in effect                     |
| `partially-superseded`    | ⚠️          | Still applies outside the scope of replacing records             |
| `superseded`             | ~~title~~   | Replaced by a newer record                                       |
| `deprecated`             | 🗑️          | No longer recommended, without a specific replacement             |

## Conventions

- One English file per decision, numbered `NNNN-short-slug.md`. Never reuse
  numbers. Titles use the bare number; prose and metadata use `ADR-NNNN`.
- Title the problem/decision area, not the selected solution.
- Copy [template.md](template.md), take the next number and add an index row.
  Omit unused optional sections. Keep metadata and index in sync.
- Accepted decisions are immutable. A changed decision gets a new ADR. Update
  the old status and `superseded-by`, and mirror it in the new `supersedes`.
  Editorial corrections that preserve meaning are allowed.
- Append supporting research as dated snapshots; do not silently rewrite
  accepted decisions or previously committed research with newer findings.
- Context explains the problem and constraints; Decision states the choice;
  Consequences includes drawbacks and risks; Options considered explains
  evidenced alternatives. Do not invent rejected options or historical motives.
- Link issue investigations instead of duplicating their logs and failed attempts.
  Open issues can remain open while an architectural choice is accepted.
- Mark selected options with ✅ in the options tables.
