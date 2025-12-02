sudo pacman -S --needed --noconfirm slock
sudo pacman -R --noconfirm light-locker xfce4-screensaver || true

xfconf-query -c xfce4-session -np /general/LockCommand -t string -s "slock"

# Neither the session nor the power manager should invoke slock.
# It will be called by our own service instead, see below.
# This is necessary, because otherwise the slock call seems to be blocking,
# and results in a call to slock, but only after you unlock the system is going to suspend mode.
# Also, if "LockCommand" is set to an empty string (like I tried before),
# xflock4 cannot lock the screen anymore (which is something I want and is mapped to Ctrl+Alt+Del).
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/lock-screen-suspend-hibernate -t bool -s false
xfconf-query -c xfce4-session -np /shutdown/LockScreen -t bool -s false

sudo cp ./slock@.service /etc/systemd/system/slock@.service
sudo systemctl enable slock@${USER}.service
