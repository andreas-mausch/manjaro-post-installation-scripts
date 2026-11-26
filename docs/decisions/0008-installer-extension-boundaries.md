---
status: accepted
date: 2026-11-26
deciders: []
supersedes: []
superseded-by: []
---

# 0008: Installer extension boundaries

> Recorded retroactively on 2026-11-26. Package separation and log streaming
> were implemented on 2026-11-25; SPICE autostart correction followed on 2026-11-26.

## Context

Variant configuration should not recompile Calamares. Installation output must
reach its public logger without exposing secret input. SPICE needs a session
agent, but the pinned desktop entry prevents systemd XDG autostart.

## Decision

Reuse the unchanged Nixpkgs Calamares package with a separate configuration
wrapper; align desktop/autostart and Polkit launchers with that executable.
Use public Calamares extension/process interfaces, including a debug callback
for live installation output. Keep secret/configuration commands off that
streaming path. When users select SPICE integration, correct only the
`X-systemd-skip` key and use the normal XDG generator rather than a custom service.

## Consequences

- **Positive:** Settings-only changes avoid recompilation; integrations stay
  local and use existing framework lifecycle mechanisms.
- **Negative:** Wrapper/launcher/policy alignment and pinned public APIs require
  regression coverage. SPICE needs a packaged upstream-entry workaround.
- **Risks / neutral:** Original Nix output is not sanitized. SPICE autostart
  does not fix the separate Wayland clipboard limitation; the upstream user
  service proposal was unavailable in the pinned revision.

## Options considered

| Option                            | Verdict      | Why                                                      |
| --------------------------------- | ------------ | -------------------------------------------------------- |
| Separate Calamares wrapper        | ✅           | Keeps compiled package independent of settings           |
| Package extraWrapperArgs override | Replaced     | Made configuration paths trigger recompilation           |
| Inherited stdout alone            | Insufficient | Did not provide live Toggle log output                   |
| Minimal XDG SPICE entry fix       | ✅           | Validated fresh-login startup using the normal generator |
| Additional SPICE user service     | Not selected | Unnecessary custom lifecycle for the validated local fix |

## References

- Git `c1a767f`, `a9ebb56`, `42f50f3`, `ad7b1dc`, `9fff037`.
- [Package/wrapper issue](../issues/solved/2026-11-25_calamares-rebuilds-for-configuration.md).
- [Live logging](../issues/solved/2026-11-25_installer-live-log-output.md).
- [SPICE startup](../issues/2026-11-26_spice-session-autostart.md).
- [Wayland clipboard](../issues/2026-11-26_spice-wayland-clipboard.md).
