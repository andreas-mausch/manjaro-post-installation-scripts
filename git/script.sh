sudo pacman -S --needed --noconfirm tk aspell aspell-en aspell-de
sudo pacman -S --needed --noconfirm tig lazygit
sudo pacman -S --needed --noconfirm bat git-delta

git config --global alias.lg "log --abbrev-commit --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:'%C(blue)%h%C(reset) %C(dim white)%ad%C(reset) %C(green)%<(8,trunc)%an%C(reset)%C(yellow)%d%C(reset) %C(white)%s%C(reset)'"
git config --global alias.tidy.branches "! git branch --merged origin/master | grep -v \* | xargs --no-run-if-empty git branch -D && git remote update origin --prune"
git config --global alias.tidy.tags "! git tag -l | xargs git tag -d && git fetch --tags"
git config --global alias.tidy "! git tidy.branches && git tidy.tags"
git config --global alias.root "hash-object -t tree /dev/null"
git config --global alias.tags "lg --tags --no-walk"
git config --global alias.branches "! (export default_branch=\"\$(git default)\" && echo -e \"Default branch: \\e[34m\${default_branch}\\e[0m\" && git for-each-ref --format='%(refname)' refs/heads refs/remotes/origin | xargs -I{} bash -c 'ahead=\$(git rev-list --count origin/\${default_branch}..{}); behind=\$(git rev-list --count {}..origin/\${default_branch}); if (( \"\$ahead\" > 0 )); then ahead_s=\"\\e[32m+\$ahead\\e[0m\"; else ahead_s=\"\e[90m+\$ahead\e[0m\"; fi; if (( \"\$behind\" > 0 )); then behind_s=\"\\e[31m-\$behind\e[0m\"; else behind_s=\"\\e[90m-\$behind\e[0m\"; fi; last_change=\$(git for-each-ref --format=\"%(committerdate:relative)\" {}); short_name=\$(git for-each-ref --format=\"%(refname:short)\" {}); printf \"%15b %15b   %-50.50s   \\e[90m%-20.20s\\e[0m\n\" \"\${ahead_s}\" \"\${behind_s}\" \"\${short_name}\" \"\${last_change}\"')"
git config --global alias.default "! git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'"
git config --global alias.file-size "! git status --porcelain | awk '{print \$2}' | xargs ls -hl | sort -r -h | awk '{print \$5 \"\t\" \$9}'"

# See here: https://github.com/prati0100/git-gui/issues/29
git config --global gui.usettk 0
git config --global gui.fontui "-family \"DejaVu Sans\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"
git config --global gui.fontdiff "-family \"Source Code Pro\" -size 12 -weight normal -slant roman -underline 0 -overstrike 0"

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

mkdir -p ~/.config/lazygit/
cp ./lazygit.config.yml ~/.config/lazygit/config.yml

mkdir -p ~/.config/bat/
cp ./bat.config ~/.config/bat/config
