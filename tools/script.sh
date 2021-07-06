#!/usr/bin/env bash

sudo pacman -S --noconfirm \
  audacity \
  avidemux-qt \
  dhex \
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
  tiv # You might need to run it like this: yay -S --mflags --skipinteg tiv
