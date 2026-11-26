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
Strix Halo mini PC; the display is a TV attached over HDMI, there is no
internal eDP panel (corrected 2026-11-26). The VM used QXL/SPICE, so the
common software layer is Plasma/KWin while the driver layer differs.
amdgpu ships with the kernel, so the driver version follows the kernel
version; the DMUB/DC firmware comes from the same pinned nixpkgs.

## Hypotheses

1. amdgpu HDMI DPMS wake regression on Strix. Upstream reports an external
   HDMI output failing to wake from DPMS/consoleblank since kernel 6.18
   (Strix, kernel 6.18.3, reported January 2026; internal eDP unaffected,
   no dmesg messages, no fix recorded on the list). A second report on Strix
   Halo hardware shows HDMI cycling or never waking after DPMS off, needing
   a reboot, also without dmesg errors, with HDMI link retraining suspected.
   Kernel 7.3.5 is far past the 6.18 regression start. TV-specific standby
   behavior (deep power save, HPD/link retraining quirks) may contribute.
   eDP-only mechanisms (Panel Replay/PSR) do not apply to this setup.
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
task 4), so evidence during a future blank needs temporary SSH or the TV
console path.

- After rebooting, temporarily enable SSH on the M5 and shorten the blank
  timeout (for example one minute) to reproduce and investigate the state
  while it is still frozen.
- Separate driver from Plasma without any KDE idle path: on a text console,
  boot with kernel parameter `consoleblank=60`, stay on the VT, let it
  blank and wake with a key. A dead HDMI output there is pure driver/link
  territory and implicates no KWin code; it also matches the upstream
  reproduction exactly.
- While black: switch the TV input away and back, and toggle the TV power,
  to test whether the link recovers only via TV-side renegotiation.
- While black, over SSH or the console: check
  `journalctl -b 0 | grep -iE 'kwin|amdgpu|drm|dpms'` around the blanking
  event. KWin lines like `Setting dpms mode failed` or
  `Atomic modeset test failed` point to hypothesis 2; note that the
  upstream HDMI reports show no dmesg output at all.
- While black: `cat /sys/class/drm/card*/card-*/status` to see whether the
  HDMI connector still reports `connected`.
- Test recovery without reboot from SSH (each result localizes the fault):
  `kscreen-doctor` output re-enable, an explicit `dpms on` via sysfs, then
  `systemctl restart sddm`. Recovery via `sddm` restart implicates KWin;
  no recovery through any userspace path implicates the driver pipeline.
- Test whether disabling automatic screen shutdown in Plasma prevents the
  failure on the M5, mirroring the pending VM countercheck. Until the cause
  is known, this is the practical mitigation.
- Kernel comparison: the upstream regression starts with 6.18 (6.17
  worked). If the pinned nixpkgs offers an older `linuxPackages_*` with
  Strix Halo support, test it as a mitigation while upstream triage runs.

## Evidence

- 2026-11-26: User report confirming the failure on the Bosgame M5 after
  10 minutes of idle, ruling out a purely VM-specific cause.
- 2026-11-26: User report confirming that neither mouse/keyboard activity
  nor Ctrl+Alt+F3 restored an image or showed any response.
- 2026-11-26: During the black screen the system remained reachable; the
  network and Gufo inference kept serving requests, confirming the fault
  is limited to the display path.
- 2026-11-26: User correction: the M5 drives a TV over HDMI and has no
  internal eDP panel, ruling out eDP-only mechanisms such as Panel Replay
  or PSR and pointing to the HDMI DPMS wake regression reports instead.
