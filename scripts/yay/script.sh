#!/usr/bin/env bash

cd /tmp
rm -rf ./yay-build
mkdir ./yay-build
cd ./yay-build
git clone --quiet https://aur.archlinux.org/yay.git
cd yay
makepkg --syncdeps --install --noconfirm
