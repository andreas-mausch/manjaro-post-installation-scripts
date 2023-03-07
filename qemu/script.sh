sudo pacman -S --noconfirm libvirt virt-manager virt-viewer

sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

# You might want to edit /etc/libvirt/libvirtd.conf
# to use your own user.
# unix_sock_group = "libvirt"
# unix_sock_rw_perms = "0770"
# sudo usermod -a -G libvirt $(whoami)
# sudo systemctl restart libvirtd.service
