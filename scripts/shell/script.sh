#!/usr/bin/env bash

sudo pacman -S --noconfirm fish

cp /etc/pam.d/chsh ./chsh.backup
sudo cp ./chsh /etc/pam.d/
chsh -s /usr/bin/fish
sudo cp ./chsh.backup /etc/pam.d/chsh
rm ./chsh.backup
