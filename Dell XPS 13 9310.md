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

# tlp

I use tlp to limit the CPU and GPU frequencies.

Reducing the GPU frequency helped a lot to save some power on YouTube videos.
If you play games you want to increase it of course.

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
