sudo pacman -S --needed --noconfirm helix
sudo pacman -S --needed --noconfirm typescript-language-server
sudo pacman -S --needed --noconfirm vue-language-server

mkdir -p ~/.config/helix/
cp ./config.toml ~/.config/helix/
