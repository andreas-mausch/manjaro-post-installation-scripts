Bluetooth, WiFi, Fingerprint sensor worked out of the box on Kernel 6.1.

# Webcam

For the closed-source webcam support, I had success using:

https://github.com/stefanpartheym/archlinux-ipu6-webcam

Make sure to install the right `linux-headers` first.

# Microphone

It is muted by default (in a hidden ALSA setting, not in PulseAudio).

https://wiki.archlinux.org/title/Dell_XPS_17_(9720)

> The laptop has several mic channels and the appropriate channel has to be unmuted before the mic will work. Open alsamixer, press F6, then in sof-soundwire:
>
> - Select Playback (F3)
> - Under Playback, select rt714 ADC 22 Mux and set it to DMIC1
> - Select Capture (F4)
> - Make sure PGA5.0 5 Master is unmuted and and the two rt714 FU02 channels are unmuted.
>
> Make sure both the left and right microphones for the PGA5.0 channel (use keys ; and ') are selected. Other than the above mentioned channels in Playback and Capture, none of the other channels appears to able to influence recorded audio. 

# Sound speaker buzzing

https://wiki.archlinux.org/title/PulseAudio/Troubleshooting#Pops_when_starting_and_stopping_playback

```{data-filename=~/.config/pulse/default.pa}
.include /etc/pulse/default.pa
.nofail
unload-module module-suspend-on-idle
.fail
```

See also: https://unix.stackexchange.com/questions/513489/buzzing-when-not-playing/513491#513491

To me it seems like the coil-whine of the CPU is amplified by the speaker if the `module-suspend-on-idle` is loaded. Very annoying.
Even when unloaded, I can still hear the same buzzing when I hold my ear right next to the keyboard, just way quieter and not annoying anymore.
