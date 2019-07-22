#!/usr/bin/env bash

sudo pacman -S --noconfirm conky
mkdir -p ~/.config/conky/
cp ./.conkyrc ~/.config/conky/
cp ./conky.desktop ~/.config/autostart/
