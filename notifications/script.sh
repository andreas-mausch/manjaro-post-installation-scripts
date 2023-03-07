gsettings list-keys org.gnome.nm-applet
gsettings set org.gnome.nm-applet disable-disconnected-notifications "true"
gsettings set org.gnome.nm-applet disable-connected-notifications "true"
gsettings set org.gnome.nm-applet suppress-wireless-networks-available "true"

# Disable "Einrasten der Tasten ist aktiviert"
xfconf-query -c xfce4-notifyd -p /applications/muted_applications -n -t string -s xfce4-settings-helper -a
