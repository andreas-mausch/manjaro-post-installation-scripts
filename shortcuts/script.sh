#!/usr/bin/env bash

cp ./xfce4-keyboard-shortcuts.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

echo "keycode 0x31 = 0xfb" >> ~/.Xmodmap # Map dead dircumflex to some unused key (0xfb = û)
echo "keycode 0x42 = NoSymbol" >> ~/.Xmodmap # Map capslock to nothing
