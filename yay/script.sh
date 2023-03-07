cd /tmp
rm -rf ./yay-build
mkdir ./yay-build
cd ./yay-build
git clone --quiet https://aur.archlinux.org/yay.git
cd yay
makepkg --syncdeps --install --noconfirm

sudo sed -i "s,PKGEXT='.pkg.tar.xz',PKGEXT='.pkg.tar',g" /etc/makepkg.conf
