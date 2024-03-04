# Device

I have the 3456x2160 OLED model.

I had some trouble with the power consumption in general.
It is well-known that the OLED model consumes much more than the LCD,
however I was able to reduce the amount to a point I can comfortably use it for several hours.

By default it used up to 18-20 W at peaks and I reduced it to ~5-6 W idle, ~10-11 W at YouTube and ~13-14 W max.

Compared to the XPS 13 9315 with a 1920x1200 display, which uses 2-3 W idle, 7-8 W at YouTube, 16 W max,
I am happy to trade off the much better display for some battery life.
It is close though, because the 9315 is the only Linux laptop I own
which can almost last as long as my MacBook Air, and I like that very much.

Also, the less input lag on the OLED display is noticable to me.

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
