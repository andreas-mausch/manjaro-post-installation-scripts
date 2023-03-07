sudo pacman -S --noconfirm slock
sudo pacman -R --noconfirm light-locker

xfconf-query -c xfce4-session -p /general/LockCommand -s "slock"

sudo cp ./slock@.service /etc/systemd/system/slock@.service
sudo systemctl enable slock@${USER}.service
