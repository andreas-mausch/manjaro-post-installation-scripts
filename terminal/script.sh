#!/usr/bin/env bash

xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Source Code Pro 10"

sudo pacman -S --noconfirm alacritty
mkdir -p ~/.config/alacritty
cp ./alacritty.yml ~/.config/alacritty
