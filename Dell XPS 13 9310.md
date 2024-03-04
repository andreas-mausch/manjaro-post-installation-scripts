# Device

I have the OLED model.

I had some trouble with the power consumption in general.
It is well-known that the OLED model consumes much more than the LCD,
however I was able to reduce the amount to a point I can comfortably use it for several hours.

By default it used up to 18-20 W at peaks and I reduced it to ~5 W idle, ~9-10 W at YouTube and ~12-13 W max.

# Intel tools

Make sure to install these to have `intel_gpu_top` and `intel_gpu_frequency` available.

```bash
sudo pacman -S intel-gpu-tools intel-media-driver libva-utils
```

# throttled

I use throttled to set the max TDP to 9 W.
This is the same as the XPS 13 9315 model has as a default,
and I prefer more lifetime over more cpu power.

```bash
sudo pacman -S throttled
sudo /usr/lib/throttled/throttled.py --monitor
systemctl status throttled.service
systemctl start throttled.service
systemctl enable throttled.service
```

```{data-filename=/etc/throttled.conf}
...

[BATTERY]
# Update the registers every this many seconds
Update_Rate_s: 30
# Max package power for time window #1
PL1_Tdp_W: 9
# Time window #1 duration
PL1_Duration_s: 28
# Max package power for time window #2
PL2_Tdp_W: 9
# Time window #2 duration
PL2_Duration_S: 0.002
# Max allowed temperature before throttling
Trip_Temp_C: 75
# Set cTDP to normal=0, down=1 or up=2 (EXPERIMENTAL)
cTDP: 1
# Disable BDPROCHOT (EXPERIMENTAL)
Disable_BDPROCHOT: False

...
```

# tlp

Additionally, I use tlp to limit the GPU frequency.
Maybe I should use tlp only and drop throttled, and use `CPU_SCALING_MAX_FREQ_ON_BAT`
or `CPU_MAX_PERF_ON_BAT` instead of setting a TDP limit.

Reducing the GPU frequency helped a lot to save some power on YouTube videos.


```bash
sudo pacman -S tlp
systemctl status tlp.service
systemctl start tlp.service
systemctl enable tlp.service
```

```{data-filename=/etc/tlp.conf}
...

TLP_DEFAULT_MODE=BAT
TLP_PERSISTENT_DEFAULT=1

CPU_ENERGY_PERF_POLICY_ON_BAT=power

INTEL_GPU_MIN_FREQ_ON_BAT=100
INTEL_GPU_MAX_FREQ_ON_BAT=400
INTEL_GPU_BOOST_FREQ_ON_BAT=500

CPU_MAX_PERF_ON_BAT=40
CPU_BOOST_ON_BAT=0

...
```
