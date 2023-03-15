sudo pacman -S --needed --noconfirm lightdm-slick-greeter lightdm-settings

# Note: You manually need to edit /etc/lightdm/lightdm.conf and set
# greeter-session=lightdm-slick-greeter

# Login background for slick-greeter
# Taken from here: https://github.com/ooxxvv/basil-tw
sudo cp ./login-background.png /usr/share/backgrounds/
sudo chown root:root /usr/share/backgrounds/login-background.png
sudo sed -i "s,^background=.*\$,background=/usr/share/backgrounds/login-background.png,g" /etc/lightdm/slick-greeter.conf
