sudo pacman -S --needed --noconfirm gajim python-gnupg python-gpgme python-axolotl-curve25519 python-qrcode farstream gstreamer gst-libav gst-plugin-gtk gst-plugins-base gst-plugins-ugly gsound gspell libvoikko nuspell hunspell

# omemo is not a plugin anymore, but merged into Gajim:
# https://dev.gajim.org/gajim/gajim-plugins/-/commit/719de5a1f4f00bbdd293828973f4bcc5031d1683

mkdir -p ~/.local/share/gajim/plugins/openpgp/
wget --quiet --directory-prefix /tmp/ https://ftp.gajim.org/plugins/master/openpgp/openpgp_1.6.2.zip
unzip -q /tmp/openpgp_1.6.2.zip -d ~/.local/share/gajim/plugins/openpgp/
rm /tmp/openpgp_1.6.2.zip

mkdir -p ~/.local/share/gajim/plugins/pgp/
wget --quiet --directory-prefix /tmp/ https://ftp.gajim.org/plugins/master/pgp/pgp_1.6.0.zip
unzip -q /tmp/pgp_1.6.0.zip -d ~/.local/share/gajim/plugins/pgp/
rm /tmp/pgp_1.6.0.zip
