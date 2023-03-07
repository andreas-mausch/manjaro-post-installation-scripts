sudo pacman -S --noconfirm audacious

mkdir -p ~/.local/share/audacious/Skins/
cp ./135799-winamp_classic.wsz ~/.local/share/audacious/Skins/

mkdir -p ~/.config/audacious/
cp ./config ~/.config/audacious/
echo "skin=`realpath ~/.local/share/audacious/Skins/135799-winamp_classic.wsz`" >> ~/.config/audacious/config
