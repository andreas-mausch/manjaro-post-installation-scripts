sudo pacman -S --needed --noconfirm manjaro-pipewire wireplumber
sudo pacman -S --needed --noconfirm audacious

mkdir -p ~/.local/share/audacious/Skins/
cp ./135799-winamp_classic.wsz ~/.local/share/audacious/Skins/

mkdir -p ~/.config/audacious/
cp ./config ~/.config/audacious/
echo "skin=`realpath ~/.local/share/audacious/Skins/135799-winamp_classic.wsz`" >> ~/.config/audacious/config

# Check usage of pipewire via:
# pactl info | grep "Server Name"

# There is a "Global Hotkeys plugin", but I'd rather let the
# PulseAudio panel plugin for XFCE control the media keys,
# see xfce/xfce4-panel.xml
