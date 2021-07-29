#!/usr/bin/env bash

sudo pacman -S --noconfirm \
  audacity \
  avidemux-qt \
  bless \
  bpytop \
  colordiff \
  dhex \
  gpxsee \
  gthumb \
  handbrake \
  httpie \
  meld \
  ncdu \
  pv \
  smartmontools \
  youtube-dl
yay -S --noconfirm \
  s-tui \
  apostrophe \
  timg

gsettings set org.gnome.gthumb.browser sort-type "exif::photo::datetimeoriginal"
gsettings set org.gnome.gthumb.browser properties-visible "true"
