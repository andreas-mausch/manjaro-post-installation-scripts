sudo pacman -S --needed --noconfirm mpv

mkdir -p ~/.config/mpv/lua-settings
mkdir -p ~/.config/mpv/scripts

cp ./mpv.conf ~/.config/mpv/

# For thumbnail generation:
# https://github.com/TheAMM/mpv_thumbnail_script/issues/53#issuecomment-594277997
# The lua scripts need to be built from master, the release is outdated.
# ./concat_files.py cat_osc.json
# ./concat_files.py cat_server.json
cp ./mpv_thumbnail_script_client_osc.lua ~/.config/mpv/scripts/
cp ./mpv_thumbnail_script_server.lua ~/.config/mpv/scripts/

cp ./mpv_thumbnail_script.conf ~/.config/mpv/lua-settings/
