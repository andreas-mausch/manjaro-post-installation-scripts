sudo pacman -S --needed --noconfirm geeqie

mkdir -p ~/.config/geeqie/
cp ./accels ~/.config/geeqie/

# Set this in geeqierc.xml or in Preferences/Behavior/Play video by left click on image
# image_l_click_video = "true"
# https://github.com/BestImageViewer/geeqie/issues/728

# Unfortunately, geeqie cannot be configured to work with
# Left/Right arrow keys for next and previous image. :(
# That's why I have mapped them to comma/period.

# Some useful default keybindings:
# EXIF: Ctrl+E
# Show file list: Ctrl+H
# Fullscreen: F
# Info overlay: I

# OSD:
# %formatted.SubjectDistance%%Exif.OlympusFi.FocusDistance%
# %formatted.FocalLength% (35mm: %formatted.FocalLength35mmFilm%)
# %lua.lensID%
