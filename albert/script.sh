#!/usr/bin/env bash

sudo pacman -S --noconfirm albert
mkdir -p ~/.config/albert/org.albert.frontend.qmlboxmodel/
cp ./albert.conf ~/.config/albert/
cp ./style_properties.ini ~/.config/albert/org.albert.frontend.qmlboxmodel/
ln -s /usr/share/applications/albert.desktop /home/neonew/.config/autostart/albert.desktop
