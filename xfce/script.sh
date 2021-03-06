#!/usr/bin/env bash

rm -f ~/.config/autostart/manjaro-hello.desktop

xfconf-query -c xfwm4 -p /general/workspace_count -s 1

# Theme

xfconf-query -c xsettings -p /Net/ThemeName -s "Matcha-dark-azul"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"

# Desktop Icons

xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-removable -s "false"
xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-home -s "false"
xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-filesystem -s "false"
xfconf-query -R -c xfce4-desktop -p /desktop-icons/file-icons/show-trash -s "false"

# Thunar Sidebar Icons

xfconf-query -c thunar -p /hidden-bookmarks -t string -t string -s "computer:///" -s "trash:///"
xfconf-query -c thunar -p /last-show-hidden -s "true"
xfconf-query -c thunar -p /last-view -s "ThunarDetailsView"

# Thunar Bookmarks

mkdir -p ~/.config/gtk-3.0/
echo "file:///home/neonew/Documents" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Downloads" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Music" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Pictures" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Videos" >> ~/.config/gtk-3.0/bookmarks

# Panel configuration

cp ./xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

# Mousepad

dconf write /org/xfce/mousepad/preferences/view/show-line-numbers true
dconf write /org/xfce/mousepad/preferences/view/tab-width 'uint32 4'
dconf write /org/xfce/mousepad/preferences/window/statusbar-visible true
dconf write /org/xfce/mousepad/preferences/window/opening-mode "'window'"
