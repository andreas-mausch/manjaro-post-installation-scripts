#!/usr/bin/env bash

sudo pacman -S --noconfirm virtualbox virtualbox-host-dkms
yay -S --noconfirm virtualbox-ext-oracle

# On Arch/Manjaro guest machines, run this:
# sudo pacman -S virtualbox-guest-utils
# https://wiki.archlinux.org/title/VirtualBox/Install_Arch_Linux_as_a_guest
