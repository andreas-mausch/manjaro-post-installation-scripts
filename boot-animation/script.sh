# Source of theme: https://github.com/adi1090x/plymouth-themes
sudo mkdir -p /usr/share/plymouth/themes/motion/
sudo unzip -q ./motion.zip -d /usr/share/plymouth/themes/motion/
sudo plymouth-set-default-theme -R motion

# I had to change a line in
# sudo nano /etc/mkinitcpio.conf
# MODULES="i915"
# See here: https://wiki.archlinux.org/title/plymouth
