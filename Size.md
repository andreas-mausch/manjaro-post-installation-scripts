# Desktop ISO size analysis

Measured on 2026-11-26 for the Desktop ISO built with NetworkManager and iwd.
This is the baseline before firmware and speech-voice reductions.

- ISO size: **12,280,113,152 bytes** (12.28 GB / 11.44 GiB).
- Store SquashFS: **12,215,484,416 bytes**.
- Remaining ISO contents and overhead: about **65 MB**.
- Store closure: **1,854 paths**. NAR size totals 12.18 GiB; regular-file payload totals 12.09 GiB.
  These logical totals are not the physical SquashFS size: deduplication and metadata affect image size.

## Largest components

Sizes below are logical regular-file sizes before SquashFS deduplication, not additive predictions of ISO savings.

| Component                       | Size       | Origin                                                |
| ------------------------------- | ---------- | ----------------------------------------------------- |
| Uncompressed Linux firmware     | 1,928 MiB  | Explicit offline assembly dependency                  |
| Compressed Linux firmware       | 824 MiB    | Regular system firmware                               |
| Two MBROLA voice packages        | 903 MiB    | Speech Dispatcher in live and target systems           |
| LLVM libraries                  | 550 MiB    | Mesa graphics stack                                   |
| QtWebEngine                     | 420 MiB    | KDE Discover                                          |
| Firefox                         | 397 MiB    | Browser                                               |
| MariaDB server                  | 335 MiB    | Akonadi                                               |
| Plasma workspace wallpapers     | 295 MiB    | KDE default packages                                  |
| Two Nixpkgs source trees         | 385 MiB    | Archived offline inputs and live Nix registry          |

Both firmware outputs are from `linux-firmware-20261019`. The uncompressed output is referenced directly by
the live system through `build/offline.nix`; the compressed output is referenced by the system firmware bundle.
Equal version strings alone do not establish that every file or firmware consumer can use either representation.

The MBROLA packages occupy approximately 644.5 and 258.6 MiB respectively. The upstream installation-media
overlay limits the live package to one voice per language; the target package contains a larger voice set.

The prepared Desktop target closure accounts for 9.36 GiB of logical regular-file payload, including retained
sources. The complete live closure is 12.09 GiB. Shared dependencies are counted once within each closure;
these figures must not be added together.

## Reduced ISO comparison

The rebuilt Desktop ISO reuses the zstd firmware output for offline assembly
and disables optional MBROLA support while retaining eSpeak and screen readers.
SquashFS compression settings are unchanged.

| Image | Exact size (bytes) | GB | GiB |
| --- | ---: | ---: | ---: |
| Baseline | 12,280,113,152 | 12.28 | 11.44 |
| Reduced | 9,596,540,928 | 9.60 | 8.94 |
| Reduction | 2,683,572,224 | 2.68 | 2.50 |

The actual ISO reduction is **21.85%**. Sizes were compared using the saved
baseline and `stat` on `result-desktop-reduced/iso/nixos-desktop.iso`.
This measures both changes together, not their individual contributions.
The build completed; live hardware behavior and compressed-only firmware
usability during offline installation still require runtime verification.

## Method

Read the completed ISO directory with xorriso, obtain the exact SquashFS input paths from the ISO's
closure-info derivation, and inspect store references, NAR sizes and regular-file sizes. Trace dependency
paths to identify why the largest components are retained. No ISO contents or runtime settings were changed
as part of the baseline measurement.
