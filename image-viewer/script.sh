sudo pacman -S --needed --noconfirm geeqie

mkdir -p ~/.config/geeqie/
cp ./accels ~/.config/geeqie/

# Unfortunately, geeqie cannot be configured to work with
# Left/Right arrow keys for next and previous image. :(
# That's why I have mapped them to comma/period.

# Some useful default keybindings:
# EXIF: Ctrl+E
# Fullscreen: F
# Info overlay: I
