#!/usr/bin/env bash

sudo pacman -S --noconfirm xcape

cp ./xcape.desktop ~/.config/autostart/
cp ./xfce4-keyboard-shortcuts.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/
