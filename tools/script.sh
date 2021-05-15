#!/usr/bin/env bash

sudo pacman -S --noconfirm \
  audacity \
  avidemux-qt \
  gthumb \
  handbrake \
  httpie \
  meld \
  ncdu \
  youtube-dl
yay -S --noconfirm \
  fsearch-git \
  s-tui \
  apostrophe \
  tiv

# fsearch config changes (located at ~/.config/fsearch/fsearch.conf)
# [Interface]
# restore_column_configuration=true
# restore_window_size=true
