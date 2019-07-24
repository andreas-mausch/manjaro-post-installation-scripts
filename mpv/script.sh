#!/usr/bin/env bash

sudo pacman -S --noconfirm mpv

mkdir -p ~/.config/mpv/
cp ./mpv.conf ~/.config/mpv/
