sudo pacman -S --needed --noconfirm autorandr

# Do not enable the service - we will only call autorandr manually.
# Otherwise my displays and/or the display driver change rapidly back and forth,
# until something breaks and the display stays black.

# sudo systemctl enable --now autorandr.service

# Also disable the udev rule
sudo mv /lib/udev/rules.d/40-monitor-hotplug.rules /lib/udev/rules.d/40-monitor-hotplug.rules.disabled
