#!/usr/bin/env bash

sudo pacman -S --noconfirm tk aspell aspell-en aspell-de
sudo pacman -S --noconfirm tig
sudo pacman -S --noconfirm diff-so-fancy

git config --global alias.lg "log --abbrev-commit --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:'%C(blue)%h%C(reset) %C(dim white)%ad%C(reset) %C(green)%<(8,trunc)%an%C(reset)%C(yellow)%d%C(reset) %C(white)%s%C(reset)'"
git config --global alias.tidy.branches "! git branch --merged origin/master | grep -v \* | xargs --no-run-if-empty git branch -D && git remote update origin --prune"
git config --global alias.tidy.tags "! git tag -l | xargs git tag -d && git fetch --tags"
git config --global alias.tidy "! git tidy.branches && git tidy.tags"
git config --global alias.first "hash-object -t tree /dev/null"
git config --global alias.tags "lg --tags --no-walk"
git config --global alias.branches "! git for-each-ref refs/heads refs/remotes/origin --format='%(refname:short)' | xargs -i sh -c 'ahead=\$(git rev-list --count origin/master..{}); behind=\$(git rev-list --count {}..origin/master); printf \"%4s %4s {}\n\" \"+\$ahead\" \"-\$behind\"'"

git config --global gui.fontui "-family \"Droid Sans\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"
git config --global gui.fontdiff "-family \"Droid Sans Mono\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"

git config --global core.quotepath false

git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
git config --global interactive.diffFilter "diff-so-fancy --patch"

mkdir -p ~/.config/git/
cp ./gitk ~/.config/git/
