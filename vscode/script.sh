#!/usr/bin/env bash

sudo pacman -S --noconfirm code

code --install-extension EditorConfig.EditorConfig
code --install-extension dbaeumer.vscode-eslint
code --install-extension eamodio.gitlens
code --install-extension octref.vetur

mkdir -p ~/.config/Code\ -\ OSS/User/
cp ./settings.json ~/.config/Code\ -\ OSS/User/
