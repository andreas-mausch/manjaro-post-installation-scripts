#!/usr/bin/env bash

sudo pacman -S --noconfirm code

code --install-extension EditorConfig.EditorConfig
code --install-extension dbaeumer.vscode-eslint
code --install-extension drrouman.git-coauthors
code --install-extension eamodio.gitlens
code --install-extension octref.vetur
code --install-extension stylelint.vscode-stylelint

mkdir -p ~/.config/Code\ -\ OSS/User/
cp ./settings.json ~/.config/Code\ -\ OSS/User/
