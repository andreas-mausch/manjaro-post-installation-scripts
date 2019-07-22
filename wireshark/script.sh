#!/usr/bin/env bash

sudo pacman -S --noconfirm wireshark-qt
sudo gpasswd -a $USER wireshark
