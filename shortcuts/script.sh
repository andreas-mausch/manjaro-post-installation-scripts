#!/usr/bin/env bash

cp ./xfce4-keyboard-shortcuts.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

echo "keycode 0x42 = 0xfb" >> ~/.Xmodmap # Map capslock to some unused key (0xfb = û)
