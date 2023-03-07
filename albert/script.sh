sudo pacman -S --noconfirm muparser
paru -S --noconfirm albert

mkdir -p ~/.config/albert/org.albert.frontend.qmlboxmodel/
cp ./albert.conf ~/.config/albert/
cp ./.albertignore ~/
ln -s /usr/share/applications/albert.desktop ~/.config/autostart/
