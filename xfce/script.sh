sudo pacman -S --needed --noconfirm xfce4-weather-plugin

rm -f ~/.config/autostart/manjaro-hello.desktop

echo "Touchpad.."
sudo cp ./30-touchpad.conf /etc/X11/xorg.conf.d/

echo "Workspace.."
# xfconf-query -c xfce4-keyboard-shortcuts -l -v | grep -i workspace
xfconf-query -c xfwm4 -np /general/workspace_count -t int -s 1

echo "Power.."

xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/brightness-step-count -t uint -s 4
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/inactivity-sleep-mode-on-battery -t uint -s 1 # 1 = standby
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/lid-action-on-battery -t uint -s 1 # 1 = standby
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/logind-handle-lid-switch -t bool -s false
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/show-panel-label -t int -s 1 # 1 = show battery percentage in tray, but not remaining time
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/critical-power-level -t uint -s 5

echo "Keyboard.."

xfconf-query -c keyboard-layout -np /Default/XkbLayout -t string -s eu,de
xfconf-query -c keyboard-layout -np /Default/XkbOptions/Group -t string -s grp:shifts_toggle

echo "Theme.."

xfconf-query -c xsettings -np /Net/ThemeName -t string -s "Matcha-dark-azul"
xfconf-query -c xsettings -np /Net/IconThemeName -t string -s "Papirus-Dark"

echo "Desktop Icons.."

xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-removable -t bool -s false
xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-home -t bool -s false
xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-filesystem -t bool -s false
xfconf-query -c xfce4-desktop -np /desktop-icons/file-icons/show-trash -t bool -s false

echo "Thunar Sidebar Icons.."

xfconf-query -c thunar -np /hidden-bookmarks -t string -t string -s "computer:///" -s "trash:///"
xfconf-query -c thunar -np /last-show-hidden -t bool -s true
xfconf-query -c thunar -np /last-view -t string -s "ThunarDetailsView"
xfconf-query -c thunar -np /misc-date-style -t string -s "THUNAR_DATE_STYLE_YYYYMMDD"

echo "Thunar Bookmarks.."

mkdir -p ~/.config/gtk-3.0/
echo "file:///home/neonew/Documents" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Downloads" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Music" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Pictures" >> ~/.config/gtk-3.0/bookmarks
echo "file:///home/neonew/Videos" >> ~/.config/gtk-3.0/bookmarks

echo "Thunar custom actions.."

cp ./uca.xml ~/.config/Thunar/
cp ./accels.scm ~/.config/Thunar/

echo "Panel configuration.."

cp ./xfce4-panel.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

echo "Mousepad.."

dconf write /org/xfce/mousepad/preferences/view/show-line-numbers true
dconf write /org/xfce/mousepad/preferences/view/tab-width 'uint32 4'
dconf write /org/xfce/mousepad/preferences/window/statusbar-visible true
dconf write /org/xfce/mousepad/preferences/window/opening-mode "'window'"

echo "Terminal.."

xfconf-query -c xfce4-terminal -np /color-background-vary -t bool -s true
xfconf-query -c xfce4-terminal -np /color-use-theme -t bool -s true
xfconf-query -c xfce4-terminal -np /color-palette -t string -s "rgb(37,31,31);rgb(230,131,96);rgb(148,231,107);rgb(255,172,24);rgb(70,174,222);rgb(240,85,121);rgb(214,219,172);rgb(239,239,239);rgb(94,94,94);rgb(255,169,138);rgb(149,231,107);rgb(255,172,24);rgb(70,174,222);rgb(238,94,128);rgb(214,219,172);rgb(239,239,239)"
xfconf-query -c xfce4-terminal -np /font-name -t string -s "Source Code Pro 10"
xfconf-query -c xfce4-terminal -np /misc-always-show-tabs -t bool -s false
xfconf-query -c xfce4-terminal -np /misc-bell -t bool -s false
xfconf-query -c xfce4-terminal -np /misc-borders-default -t bool -s false
xfconf-query -c xfce4-terminal -np /misc-cursor-shape -t string -s "TERMINAL_CURSOR_SHAPE_UNDERLINE"
xfconf-query -c xfce4-terminal -np /misc-default-geometry -t string -s "210x54+20+0"
xfconf-query -c xfce4-terminal -np /misc-menubar-default -t bool -s false
xfconf-query -c xfce4-terminal -np /misc-tab-close-buttons -t bool -s false
xfconf-query -c xfce4-terminal -np /misc-tab-close-middle-click -t bool -s false
xfconf-query -c xfce4-terminal -np /scrolling-bar -t string -s "TERMINAL_SCROLLBAR_NONE"
xfconf-query -c xfce4-terminal -np /scrolling-lines -t int -s 9999

# Do not show a dialog when a new display is connected (autorandr handles them instead)

xfconf-query -c displays -np /Notify -t int -s 0

# Reduce tab height

cp ./gtk.css ~/.config/gtk-3.0/

# Mousepad dark theme

# https://draculatheme.com/mousepad
mkdir -p ~/.local/share/gtksourceview-4/styles/
wget --quiet --directory-prefix ~/.local/share/gtksourceview-4/styles/ https://raw.githubusercontent.com/dracula/mousepad/3964d841ec8fa6f5b63000cc95643977b172f577/dracula.xml
gsettings set org.xfce.mousepad.preferences.view color-scheme "dracula"

# Note: Inline-Code-Blocks are not displayed correctly, see here:
# https://github.com/dracula/mousepad/pull/4
# In dracula.xml you need to change the "background" to "purple" in this line:
# <style name="def:inline-code"             foreground="background"/>

# Default applications

cp ./mimeapps.list ~/.config/

# Mute the microphone on login
mkdir -p ~/.config/autostart/
cp ./Mute\ Microphone.desktop ~/.config/autostart/
