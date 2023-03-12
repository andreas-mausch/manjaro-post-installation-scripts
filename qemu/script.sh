sudo pacman -S --needed --noconfirm virt-manager qemu-desktop libvirt edk2-ovmf dnsmasq iptables-nft
# sudo pacman -S --needed --noconfirm qemu-emulators-full

sudo systemctl enable --now libvirtd.service

sudo usermod -a -G libvirt $USER

# You might want to edit /etc/libvirt/libvirtd.conf
# to use your own user.
# unix_sock_group = "libvirt"
# unix_sock_rw_perms = "0770"
# sudo systemctl restart libvirtd.service
