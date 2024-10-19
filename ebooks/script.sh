sudo pacman -S --needed --noconfirm calibre
paru -S --needed --noconfirm yacreader

sudo pacman -S tesseract-data-deu zathura zathura-pdf-mupdf zathura-cb
mkdir -p ~/.config/zathura/
cp ./zathurarc ~/.config/zathura/

# ~/.local/share/YACReader/YACReader/YACReader.ini
# SHOW_INFO=false
# SHOW_TOOLBARS=false
#
# [shortcuts]
# CLOSE_ACTION_Y=Q
# SHOW_SHORCUTS_ACTION_Y=H
# TOGGLE_TOOL_BARS_ACTION_Y=
