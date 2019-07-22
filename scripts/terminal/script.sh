#!/usr/bin/env bash

cp ./terminalrc ~/.config/xfce4/terminal/
xfconf-query -c xsettings -p /Gtk/MonospaceFontName -s "Source Code Pro 10"
