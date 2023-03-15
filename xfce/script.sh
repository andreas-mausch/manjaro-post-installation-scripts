rm -f ~/.config/autostart/manjaro-hello.desktop

xfconf-query -c xfwm4 -np /general/workspace_count -t int -s 1

# Power settings

xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/brightness-step-count -t uint -s 4
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/inactivity-sleep-mode-on-battery -t uint -s 1 # 1 = standby
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/lid-action-on-battery -t uint -s 1 # 1 = standby
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/logind-handle-lid-switch -t bool -s false
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/show-panel-label -t int -s 1 # 1 = show battery percentage in tray, but not remaining time
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/critical-power-level -t uint -s 5

# Keyboard

xfconf-query -c keyboard-layout -np /Default/XkbLayout -t string -s eu,de
xfconf-query -c keyboard-layout -np /Default/XkbOptions/Group -t string -s grp:shifts_toggle

# Theme

xfconf-query -c xsettings -np /Net/ThemeName -t string -s "Matcha-dark-azul"
xfconf-query -c xsettings -np /Net/IconThemeName -t string -s "Papirus-Dark"

# Desktop Icons

xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-removable -t bool -s false
xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-home -t bool -s false
xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-filesystem -t bool -s false
xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-trash -t bool -s false

# Thunar Sidebar Icons

xfconf-query -c thunar -np /hidden-bookmarks -t string -t string -s "computer:///" -s "trash:///"
xfconf-query -c thunar -np /last-show-hidden -t bool -s true
xfconf-query -c thunar -np /last-view -t string -s "ThunarDetailsView"
xfconf-query -c thunar -np /misc-date-style -t string -s "THUNAR_DATE_STYLE_YYYYMMDD"

# Thunar Bookmarks

mkdir -p ~/.config/gtk-3.0/
echo "file:///home/neonew/Documents" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Downloads" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Music" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Pictures" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Videos" >> ~/.config/gtk-3.0/bookmarks

# Thunar custom actions

cp ./uca.xml ~/.config/Thunar/

# Panel configuration

cp ./xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

# Mousepad

dconf write /org/xfce/mousepad/preferences/view/show-line-numbers true
dconf write /org/xfce/mousepad/preferences/view/tab-width 'uint32 4'
dconf write /org/xfce/mousepad/preferences/window/statusbar-visible true
dconf write /org/xfce/mousepad/preferences/window/opening-mode "'window'"

# Do not show a dialog when a new display is connected (autorandr handles them instead)

xfconf-query -c displays -np /Notify -t int -s 0

# Reduce tab height

cp ./gtk.css ~/.config/gtk-3.0/

# Mousepad dark theme

# https://draculatheme.com/mousepad
mkdir -p ~/.local/share/gtksourceview-4/styles/
wget --quiet --directory-prefix ~/.local/share/gtksourceview-4/styles/ https://raw.githubusercontent.com/dracula/mousepad/3964d841ec8fa6f5b63000cc95643977b172f577/dracula.xml
gsettings set org.xfce.mousepad.preferences.view color-scheme "dracula"

# Default applications

cp ./mimeapps.list ~/.config/
