---
status: open
---

# No image after automatic screen shutdown on the Bosgame M5

## Observation

On the Bosgame M5 with the Plasma/Wayland desktop, the display turned off
after 10 minutes of idle and no image returned afterwards. This is the same
symptom previously observed only in the Desktop VM (see
[black screen after idle in the VM](2026-11-26_virtmanager-black-screen.md)).

The reproduction on real hardware shows the failure is not specific to the
VM, QXL or SPICE. A shared cause in Plasma/Wayland display power management,
possibly interacting with the GPU driver, is plausible but unconfirmed.
Mouse/keyboard activity and Ctrl+Alt+F3 produced no response and no image,
matching the VM observation where Ctrl+Alt+F3 also did not recover. During
the frozen display the system stayed fully reachable: network and Gufo
inference kept running. This rules out a kernel or GPU-compute freeze and
narrows the failure to the display path (KWin DPMS handling or the driver
output pipeline).

Versions in the tested image: nixpkgs pinned 2026-10-22
(`3ec636362e18`), KWin/Plasma 6.8.3, kernel linux 7.3.5
(`linuxPackages_latest`, read from the Full ISO). The Bosgame M5 is an AMD
Strix Halo device; the VM used QXL/SPICE, so the common software layer is
Plasma/KWin while the driver layer differs. Kernel 7.3.5 falls inside the
upstream amdgpu eDP Panel Replay regression window (reports span 7.0 to
7.3.x; no fix in 7.3.x as of 2026-11-19). amdgpu ships with the kernel, so
the driver version follows the kernel version; the DMUB/DC firmware comes
from the same pinned nixpkgs.

## Hypotheses

1. amdgpu eDP power-saving bug (Panel Replay/PSR) on Strix Halo. Upstream
   reports match the pattern: system alive over SSH, panel never returns
   after blank, VT switch shows no image. One November 2026 report fixes an
   eDP freeze with kernel parameter `amdgpu.dcdebugmask=0x400` (disables
   Panel Replay, falls back to PSR); kernel 6.18–7.3-era amdgpu display
   regressions on Strix boards are reported upstream
   (gitlab.freedesktop.org/drm/amd issues).
2. Plasma/KWin DPMS restore failure. Wake-after-screen-off bugs with the
   session alive persist beyond the Plasma 6.6 DPMS rewrite (KDE bugs
   501207, 519218, 523511). The VM journal
   (`There are no outputs - creating placeholder screen`) fits KWin/kscreen
   losing outputs, and it would explain the same symptom on unrelated
   virtual drivers.
3. Combined trigger: Plasma's DPMS off exposes the driver wake bug; both
   environments blank via the same PowerDevil/KWin path.

## Next verification

The installed systems do not enable SSH yet (planned separately as TODO
task 4), so evidence during a future blank needs an attached display or
temporary SSH.

- Attach an external monitor when the internal panel stays black: an image
  on the external output isolates the fault to the eDP path and provides a
  local console without SSH.
- After rebooting, temporarily enable SSH on the M5 and shorten the blank
  timeout (for example one minute) to reproduce and investigate the state
  while it is still frozen.
- While black, over SSH or the console: check
  `journalctl -b 0 | grep -iE 'kwin|amdgpu|drm|dpms|psr|replay'` around the
  blanking event. KWin lines like `Setting dpms mode failed` or
  `Atomic modeset test failed` point to hypothesis 2; amdgpu/DMUB errors
  or `replay_state`/`psr_state` anomalies point to hypothesis 1.
- While black: `cat /sys/class/drm/card*/card-*/status` to see whether the
  panel still reports `connected`.
- Test recovery without reboot from SSH (each result localizes the fault):
  `kscreen-doctor output.eDP-1.on`, an explicit `dpms on` via sysfs, then
  `systemctl restart sddm`. Recovery via `sddm` restart implicates KWin;
  no recovery through any userspace path implicates the driver pipeline.
- With `amdgpu.dcdebugmask=0x400` (and short 1-minute blank timeout), test
  whether the failure disappears on the M5.
- Test whether disabling automatic screen shutdown in Plasma prevents the
  failure on the M5, mirroring the pending VM countercheck.
- Compare kernel versions: if a previous `linuxPackages_*` worked, pin it
  while upstream triage runs.

## Evidence

- 2026-11-26: User report confirming the failure on the Bosgame M5 after
  10 minutes of idle, ruling out a purely VM-specific cause.
- 2026-11-26: User report confirming that neither mouse/keyboard activity
  nor Ctrl+Alt+F3 restored an image or showed any response.
- 2026-11-26: During the black screen the system remained reachable; the
  network and Gufo inference kept serving requests, confirming the fault
  is limited to the display path.
