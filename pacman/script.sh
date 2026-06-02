sudo sed -i "s,PKGEXT='.pkg.tar.zst',PKGEXT='.pkg.tar',g" /etc/makepkg.conf
sudo sed -i "s,^#Color\$,Color,g" /etc/pacman.conf

if command -v paru &> /dev/null; then
  echo "paru already installed, skipping build"
  exit 0
fi

cd /tmp
rm -rf ./paru-build
mkdir ./paru-build
cd ./paru-build
git clone --quiet https://aur.archlinux.org/paru.git
cd paru
makepkg --syncdeps --install --noconfirm
