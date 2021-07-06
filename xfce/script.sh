#!/usr/bin/env bash

rm -f ~/.config/autostart/manjaro-hello.desktop

xfconf-query -c xfwm4 -p /general/workspace_count -s 1

xfconf-query -c xsettings -p /Net/ThemeName -s "Matcha-dark-azul"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"

cp ./xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/
