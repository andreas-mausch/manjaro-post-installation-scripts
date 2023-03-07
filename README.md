This is a collection of my personal post-installation scripts after a clean Manjaro installation.

It contains all my favorite apps, settings, fonts etc.

Feel free to use and customize them.

# Install

```
sudo pacman -Syyu

./post-installation.sh clock pacman bluetooth terminal shortcuts shell slock slick-greeter browser albert calculator vscode fsearch tools gthumb ebooks git conky wireshark mpv notifications pcspeaker xfce mongo qemu autorandr
```

# HiDPI

Here are my HiDPI settings for Xfce.

```bash
xfconf-query -c xsettings -p /Gdk/WindowScalingFactor -s 2
xfconf-query -c xfwm4 -p /general/theme -s Default-hdpi
xfconf-query -c xsettings -p /Xft/DPI -s 192

echo "export QT_SCALE_FACTOR=1" >> ~/.profile
echo "export QT_SCREEN_SCALE_FACTORS=2" >> ~/.profile
echo "export QT_AUTO_SCREEN_SCALE_FACTOR=1" >> ~/.profile
echo "export QT_FONT_DPI=96" >> ~/.profile
echo "export GDK_SCALE=\${GDK_SCALE-2}" >> ~/.profile
echo "export GDK_DPI_SCALE=\${GDK_SCALE-0.5}" >> ~/.profile
```

For wine, you need to manually set the dpi in `winecfg`.

# Dell XPS 13 9315

Bluetooth, WiFi, Fingerprint sensor worked out of the box on Kernel 6.1.

## Webcam

For the closed-source webcam support, I had success using:

https://github.com/stefanpartheym/archlinux-ipu6-webcam

Make sure to install the right `linux-headers` first.

## Microphone

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
