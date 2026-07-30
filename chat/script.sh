sudo pacman -S --needed --noconfirm gajim python-gnupg python-gpgme python-axolotl-curve25519 python-qrcode farstream gstreamer gst-libav gst-plugin-gtk gst-plugins-base gst-plugins-ugly gsound gspell libvoikko nuspell hunspell

# omemo is not a plugin anymore, but merged into Gajim:
# https://dev.gajim.org/gajim/gajim-plugins/-/commit/719de5a1f4f00bbdd293828973f4bcc5031d1683

mkdir -p ~/.local/share/gajim/plugins/openpgp/
wget --quiet --output-document=/tmp/openpgp.zip https://ftp.gajim.org/plugins/master/openpgp/openpgp_1.8.2.zip
echo "d8e78a029643f74a48e184619627a26c07b4e39c4c4e4fae0aa1ef635a396b93  /tmp/openpgp.zip" | sha256sum --check --status
unzip -q /tmp/openpgp.zip -d ~/.local/share/gajim/plugins/openpgp/
rm /tmp/openpgp.zip

mkdir -p ~/.local/share/gajim/plugins/pgp/
wget --quiet --output-document=/tmp/pgp.zip https://ftp.gajim.org/plugins/master/pgp/pgp_1.8.2.zip
echo "f231364533f6893b853139e52745b003bda64aa7c9a09d07ba6aaccebb40527e  /tmp/pgp.zip" | sha256sum --check --status
unzip -q /tmp/pgp.zip -d ~/.local/share/gajim/plugins/pgp/
rm /tmp/pgp.zip
