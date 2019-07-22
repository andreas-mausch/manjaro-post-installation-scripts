#!/usr/bin/env bash

sudo pacman -S --noconfirm albert muparser
mkdir -p ~/.config/albert/org.albert.frontend.qmlboxmodel/
cp ./albert.conf ~/.config/albert/
cp ./style_properties.ini ~/.config/albert/org.albert.frontend.qmlboxmodel/
ln -s /usr/share/applications/albert.desktop ~/.config/autostart/albert.desktop
