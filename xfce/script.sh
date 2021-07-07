#!/usr/bin/env bash

rm -f ~/.config/autostart/manjaro-hello.desktop

xfconf-query -c xfwm4 -p /general/workspace_count -s 1

xfconf-query -c xsettings -p /Net/ThemeName -s "Matcha-dark-azul"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"

xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-removable -s "false"
xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-home -s "false"
xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-filesystem -s "false"
xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-trash -s "false"

xfconf-query -c thunar -p /hidden-bookmarks -t string -t string -s "computer:///" -s "trash:///"

cp ./xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

mkdir -p ~/.config/gtk-3.0/
echo "file:///home/neonew/Documents" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Downloads" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Music" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Pictures" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Videos" >> ~/.config/gtk-3.0/bookmarks
