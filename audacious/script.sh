sudo pacman -S --needed --noconfirm manjaro-pipewire wireplumber
sudo pacman -S --needed --noconfirm audacious

mkdir -p ~/.local/share/audacious/Skins/
cp ./135799-winamp_classic.wsz ~/.local/share/audacious/Skins/

mkdir -p ~/.config/audacious/
cp ./config ~/.config/audacious/
echo "skin=`realpath ~/.local/share/audacious/Skins/135799-winamp_classic.wsz`" >> ~/.config/audacious/config

# There is a file *~/.config/audacious/plugin-registry*,
# but it's format is rather unconvenient to copy the whole file over here.
# Instead, make sure to enable the Options/Plugins/General/Global Hotkeys plugin.
# I have removed VolumeUp/Down/Mute as this is already covered by PipeWire,
# but now you can use the system-wide shortcut for XF86AudioPlay!
