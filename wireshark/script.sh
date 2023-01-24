#!/usr/bin/env bash

sudo pacman -S --noconfirm wireshark-qt termshark
sudo gpasswd -a $USER wireshark
