rm -f ~/.config/autostart/manjaro-hello.desktop

xfconf-query -c xfwm4 -p /general/workspace_count -n -s 1

# Power settings

xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/brightness-step-count -n -s 4
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/inactivity-sleep-mode-on-battery -n -s 1 # 1 = standby
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/lid-action-on-battery -n -s 1 # 1 = standby
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/logind-handle-lid-switch -n -s false
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/show-panel-label -n -s 1 # 1 = show battery percentage in tray, but not remaining time
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/critical-power-level -n -s 5

# Keyboard

xfconf-query -c keyboard-layout -p /Default/XkbLayout -n -s eu,de
xfconf-query -c keyboard-layout -p /Default/XkbOptions/Group -n -s grp:shifts_toggle

# Theme

xfconf-query -c xsettings -p /Net/ThemeName -n -s "Matcha-dark-azul"
xfconf-query -c xsettings -p /Net/IconThemeName -n -s "Papirus-Dark"

# Desktop Icons

xfconf-query -c xfce4-desktop -p /desktop-icons/file-icons/show-removable -n -s "false"
xfconf-query -c xfce4-desktop -p /desktop-icons/file-icons/show-home -n -s "false"
xfconf-query -c xfce4-desktop -p /desktop-icons/file-icons/show-filesystem -n -s "false"
xfconf-query -c xfce4-desktop -p /desktop-icons/file-icons/show-trash -n -s "false"

# Thunar Sidebar Icons

xfconf-query -c thunar -p /hidden-bookmarks -n -t string -t string -s "computer:///" -s "trash:///"
xfconf-query -c thunar -p /last-show-hidden -n -s "true"
xfconf-query -c thunar -p /last-view -n -s "ThunarDetailsView"
xfconf-query -c thunar -p /misc-date-style -n -s "THUNAR_DATE_STYLE_YYYYMMDD"

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

xfconf-query -c displays -p /Notify -n -s 0
