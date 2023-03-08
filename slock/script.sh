sudo pacman -S --needed --noconfirm slock
sudo pacman -R --noconfirm light-locker

xfconf-query -c xfce4-session -np /general/LockCommand -t string -s "slock"

sudo cp ./slock@.service /etc/systemd/system/slock@.service
sudo systemctl enable slock@${USER}.service
