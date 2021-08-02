This is a collection of my personal post-installation scripts after a clean Manjaro installation.

It contains all my favorite apps, settings, fonts etc.

Feel free to use and customize them.

# Install

```
sudo pacman -Syyu

./post-installation.sh clock yay terminal shortcuts shell autorandr albert slock slick-greeter vscode fsearch tools gthumb git conky wireshark mpv notifications pcspeaker xfce
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
