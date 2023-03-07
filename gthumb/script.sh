sudo pacman -S --needed --noconfirm gthumb

gsettings set org.gnome.gthumb.browser sort-type "exif::photo::datetimeoriginal"
gsettings set org.gnome.gthumb.browser properties-visible "true"
