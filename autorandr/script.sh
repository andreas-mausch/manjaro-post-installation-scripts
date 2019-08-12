#!/usr/bin/env bash

sudo pacman -S --noconfirm autorandr
sudo systemctl enable --now autorandr.service
