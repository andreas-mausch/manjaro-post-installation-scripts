#!/usr/bin/env bash

sudo pacman -S --noconfirm fish

cp /etc/pam.d/chsh ./chsh.backup
sudo cp ./chsh /etc/pam.d/
chsh -s /usr/bin/fish
sudo cp ./chsh.backup /etc/pam.d/chsh
rm ./chsh.backup

yay -S --noconfirm autojump-git

git clone https://github.com/oh-my-fish/oh-my-fish
cd ./oh-my-fish
./bin/install --offline --noninteractive
cd ..
rm -rf ./oh-my-fish

fish -c 'omf install eclm'

cp ./fish_variables ~/.config/fish/
cp ./config.fish ~/.config/fish/
