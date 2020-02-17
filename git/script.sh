#!/usr/bin/env bash

sudo pacman -S --noconfirm tk aspell aspell-en aspell-de

git config --global alias.lg "log --abbrev-commit --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:'%C(blue)%h%C(reset) %C(dim white)%ad%C(reset) %C(green)%<(8,trunc)%an%C(reset)%C(yellow)%d%C(reset) %C(white)%s%C(reset)'"
git config --global alias.tidy "! git branch --merged origin/master | grep -v \* | xargs --no-run-if-empty git branch -D && git remote update origin --prune"
git config --global alias.first "hash-object -t tree /dev/null"

git config --global gui.fontui "-family \"Droid Sans\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"
git config --global gui.fontdiff "-family \"Droid Sans Mono\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"

mkdir -p ~/.config/git/
cp ./gitk ~/.config/git/
