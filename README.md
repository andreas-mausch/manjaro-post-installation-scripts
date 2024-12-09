This is a collection of my personal post-installation scripts after a clean Manjaro installation.
It is based on the Manjaro XFCE Desktop.

It contains all my favorite apps, settings, fonts etc.
Feel free to use and customize them.

This is similar to what other people have in their *dotfiles* repos, but I'd rather keep the program installation commands
together with their configuration.
This way I can keep things that are connected, for example git, lazygit, tig, delta, etc., in the same folder.

# Install

```
sudo pacman -Syu
sudo pacman -S base-devel

./post-installation.sh clock pacman shortcuts shell slock slick-greeter boot-animation bluetooth xfce notifications git browser chat mpv albert calculator vscode fsearch tools image-viewer ebooks wireshark pcspeaker mongo qemu autorandr neovim helix yt-dlp gnucash
```

Note: Some packages require manual configurtion after installation.
These packages are:

- boot-animation
- browser
- qemu

See there `script.sh` files for instructions.

# HiDPI

Here are my HiDPI settings for Xfce.

```bash
xfconf-query -c xsettings -np /Gdk/WindowScalingFactor -t int -s 2
xfconf-query -c xfwm4 -np /general/theme -t string -s Default-hdpi
xfconf-query -c xsettings -np /Xft/DPI -t int -s 192

echo "export QT_SCALE_FACTOR=1" >> ~/.profile
echo "export QT_SCREEN_SCALE_FACTORS=2" >> ~/.profile
echo "export QT_AUTO_SCREEN_SCALE_FACTOR=1" >> ~/.profile
echo "export QT_FONT_DPI=96" >> ~/.profile
echo "export GDK_SCALE=\${GDK_SCALE-2}" >> ~/.profile
echo "export GDK_DPI_SCALE=\${GDK_DPI_SCALE-0.5}" >> ~/.profile
```

For wine, you need to manually set the dpi in `winecfg`.

# External hard drives

## Disable UAS

If you have trouble with external USB drives, try to disable UAS.

See these great articles about the details:

- [https://tomthorp.me/blog/problem-linux-unmounting-usb-external-drives](https://tomthorp.me/blog/problem-linux-unmounting-usb-external-drives)
- [https://leo.leung.xyz/wiki/How_to_disable_USB_Attached_Storage_(UAS)](https://leo.leung.xyz/wiki/How_to_disable_USB_Attached_Storage_(UAS))

Find usb id of the drive:

```bash
lsusb --tree --verbose
```

```{data-filename=/etc/modprobe.d/disable-uas-for-external-drives.conf}
options usb-storage quirks=0bc2:2322:u
```

Now run this and reboot:

```bash
sudo mkinitcpio --allpresets
```

## Lower dirty bytes

I had some trouble with dirty bytes set too high:

Progress when copying files was not realistic, sometimes stuck.
Also, the general performance of some drives was bad.

Fix:

```{data-filename=/etc/sysctl.d/99-decrease-dirty-bytes.conf}
# 52.428.800 = 50 MB
vm.dirty_background_bytes = 52428800
vm.dirty_bytes = 52428800
```

Track real progress of a file transfer:

```bash
watch -n 0.5 grep -e Dirty: -e Writeback: /proc/meminfo
```
