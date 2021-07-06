#!/usr/bin/env bash

gsettings list-keys org.gnome.nm-applet
gsettings set org.gnome.nm-applet disable-disconnected-notifications "true"
gsettings set org.gnome.nm-applet disable-connected-notifications "true"
gsettings set org.gnome.nm-applet suppress-wireless-networks-available "true"
