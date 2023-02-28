#!/usr/bin/env bash

sudo pacman -S --noconfirm tk aspell aspell-en aspell-de
sudo pacman -S --noconfirm tig gitui
sudo pacman -S --noconfirm bat git-delta

git config --global alias.lg "log --abbrev-commit --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:'%C(blue)%h%C(reset) %C(dim white)%ad%C(reset) %C(green)%<(8,trunc)%an%C(reset)%C(yellow)%d%C(reset) %C(white)%s%C(reset)'"
git config --global alias.tidy.branches "! git branch --merged origin/master | grep -v \* | xargs --no-run-if-empty git branch -D && git remote update origin --prune"
git config --global alias.tidy.tags "! git tag -l | xargs git tag -d && git fetch --tags"
git config --global alias.tidy "! git tidy.branches && git tidy.tags"
git config --global alias.first "hash-object -t tree /dev/null"
git config --global alias.tags "lg --tags --no-walk"
git config --global alias.branches "! git for-each-ref refs/heads refs/remotes/origin --format='%(refname:short)' | xargs -I{} sh -c 'ahead=\$(git rev-list --count origin/\$(git default)..{}); behind=\$(git rev-list --count {}..origin/\$(git default)); printf \"%4s %4s {}\n\" \"+\$ahead\" \"-\$behind\"'"
git config --global alias.default "! git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'"

git config --global gui.fontui "-family \"Droid Sans\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"
git config --global gui.fontdiff "-family \"Droid Sans Mono\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"

git config --global core.quotepath false

git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global fetch.prune true

git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.hunk-header-style "omit"
git config --global delta.line-numbers "true"
git config --global delta.navigate "true"
git config --global delta.side-by-side "true"

mkdir -p ~/.config/git/
cp ./gitk ~/.config/git/
