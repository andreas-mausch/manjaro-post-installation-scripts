cp ./xfce4-keyboard-shortcuts.xml ~/.config/xfce4/xfconf/xfce-perchannel-xml/

# Disable CapsLock
echo "clear Lock" >> ~/.Xmodmap

# Map capslock to some unused key (0xfb = û)
# but still retain functionality it if you press Shift+CapsLock
echo "keycode 0x42 = 0xfb Caps_Lock" >> ~/.Xmodmap
