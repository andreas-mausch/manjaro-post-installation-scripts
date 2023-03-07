sudo sed -i "s,PKGEXT='.pkg.tar.xz',PKGEXT='.pkg.tar',g" /etc/makepkg.conf
sudo sed -i "s,^#Color\$,Color,g" /etc/pacman.conf

cd /tmp
rm -rf ./paru-build
mkdir ./paru-build
cd ./paru-build
git clone --quiet https://aur.archlinux.org/paru.git
cd paru
makepkg --syncdeps --install --noconfirm
