---
status: workaround
status-description: "Launcher starts with libSM/libICE supplied by Nix store paths inside steam-run; benchmark rendering not yet verified."
---

# Unigine Superposition fails to start on Strix Halo

## Confirmed workaround, 2026-11-26

The Qt XCB plugin dependency check inside `steam-run` reported both
`libSM.so.6` and `libICE.so.6` as missing. The user confirmed that
`steam-run ls /tmp/sm/lib/libSM.so.6` returns “No such file or directory”,
although the library exists at that path outside the runtime environment.
The temporary output links were therefore not accessible inside
`steam-run`. Resolving them to their actual Nix store paths fixed launcher
startup; the user confirmed success. Full benchmark rendering and results
have not yet been verified.

Commands used from the Superposition installation directory:

```bash
nix build nixpkgs#libSM -o /tmp/sm
nix build nixpkgs#libICE -o /tmp/ice
sm=$(readlink -f /tmp/sm)
ice=$(readlink -f /tmp/ice)
export LD_LIBRARY_PATH=$sm/lib:$ice/lib
steam-run env LD_LIBRARY_PATH=$LD_LIBRARY_PATH ./Superposition
```

This is a manual runtime workaround, not yet a packaged fix. Supply the
library path inside `steam-run` and use actual store paths rather than
the inaccessible temporary links. No Strix Halo GPU fault was established.

## Observation

The user reports that Unigine Superposition does not start on the Strix
Halo system. Reported error:

```text
libqxcb.so not found
```

The full terminal output, Superposition version, installation source and
launch command have not yet been collected.

### Follow-up checks

- The user confirmed that the Qt launcher still fails because
  `libSM.so.6` cannot be loaded, including when launched through `steam-run`.
- `libSM` was built and `/tmp/sm/lib/libSM.so.6` exists. Attempts using
  `LD_LIBRARY_PATH` and `LD_PRELOAD` did not resolve the launcher failure;
  the preload attempt produced a cannot-preload/ignored warning. The
  reason remains unconfirmed.
- `steam-run ./bin/superposition --help` opens a black window with an FPS
  counter and extensive logging. This demonstrates that the engine can
  start, not that the benchmark scene or GPU rendering works correctly.
- The user explicitly confirmed the distinction: the engine starts, while
  the Qt launcher continues to fail on the library dependency.

The next step is to investigate the launcher's runtime environment or find
the actual benchmark launch arguments to bypass it. Do not infer benchmark
arguments from generic UNIGINE engine options.

## Possible causes — not confirmed

`libqxcb.so` is Qt's XCB platform plugin. The report may indicate a missing
plugin, an incorrect plugin search path, or a missing runtime dependency
of the plugin. It does not establish a Strix Halo GPU or driver fault.

## Remaining verification

- Run the benchmark and verify rendering and completion.
- Consider packaging the launcher with its runtime dependencies rather
  than requiring manual environment setup.

## Historical investigation steps

- Collect the complete terminal output and exact launch command.
- Record the Superposition version and installation method, and whether
  this is running in the live system or the installed system.
- Launch with `QT_DEBUG_PLUGINS=1` to inspect Qt's plugin discovery and
  loading errors.
- If the bundled `libqxcb.so` exists, inspect its dependencies for missing
  libraries before choosing a NixOS packaging or runtime workaround.
