#!/usr/bin/env bash

xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Source Code Pro 10"

sudo pacman -S --noconfirm alacritty
cp ./alacritty.yml ~/.config/alacritty

yay -S --noconfirm tdrop-git
