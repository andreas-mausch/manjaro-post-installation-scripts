sudo pacman -S --needed --noconfirm tk aspell aspell-en aspell-de
sudo pacman -S --needed --noconfirm tig lazygit
sudo pacman -S --needed --noconfirm bat git-delta
sudo pacman -S --needed --noconfirm git-filter-repo

git config --global alias.lg "log --abbrev-commit --decorate --date=format:'%Y-%m-%d %H:%M:%S' --format=format:'%C(blue)%h%C(reset) %C(dim white)%ad%C(reset) %C(green)%<(8,trunc)%an%C(reset)%C(yellow)%d%C(reset) %C(white)%s%C(reset)'"
git config --global alias.tidy.branches "! git branch --merged origin/master | grep -v \* | xargs --no-run-if-empty git branch -D && git remote update origin --prune"
git config --global alias.tidy.tags "! git fetch --prune --prune-tags --tags"
git config --global alias.tidy "! git tidy.branches && git tidy.tags"
git config --global alias.root "hash-object -t tree /dev/null"
git config --global alias.tags "for-each-ref --sort=-creatordate --color=always --format='%(color:yellow)%(refname:short)%(color:reset) %(color:blue)%(if)%(taggername)%(then)%(*objectname:short)%(else)%(objectname:short)%(end)%(color:reset) %(color:white dim)%(creatordate:format:%Y-%m-%d %H:%M:%S)%(color:reset) %(color:green)%(align:width=8,left)%(if)%(taggername)%(then)%(*committername)%(else)%(committername)%(end)%(end)%(color:reset) %(color:white)%(contents:subject)%(color:reset)' refs/tags"
git config --global alias.branches "!f() { (export default_branch=\"\$(git default)\" && echo -e \"Default branch: \\e[34m\${default_branch}\\e[0m\" && git branch \$@ --format='%(refname)' --sort='-committerdate' --sort='refname:rstrip=2' | grep --invert-match \"refs/remotes/origin/HEAD\" | xargs -I{} bash -c 'ahead=\$(git rev-list --count origin/\${default_branch}..{}); behind=\$(git rev-list --count {}..origin/\${default_branch}); if (( \"\$ahead\" > 0 )); then ahead_s=\"\\e[32m+\$ahead\\e[0m\"; else ahead_s=\"\e[90m+\$ahead\e[0m\"; fi; if (( \"\$behind\" > 0 )); then behind_s=\"\\e[31m-\$behind\e[0m\"; else behind_s=\"\\e[90m-\$behind\e[0m\"; fi; last_change=\$(git for-each-ref --format=\"%(committerdate:relative)\" {}); short_name=\$(git for-each-ref --format=\"%(refname:short)\" {}); commit_hash=\$(git for-each-ref --format=\"%(objectname:short)\" {}); commit_message=\$(git for-each-ref --format=\"%(subject)\" {}); printf \"%15b %15b   %-50.50s   \\e[90m%s\\e[0m %-40.40s   \\e[90m%-20.20s\\e[0m\n\" \"\${ahead_s}\" \"\${behind_s}\" \"\${short_name}\" \"\${commit_hash}\" \"\${commit_message}\" \"\${last_change}\"') }; f"
git config --global alias.default "! git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'"
git config --global alias.file-size "! git status --porcelain | awk '{print \$2}' | xargs ls -hl | sort -r -h | awk '{print \$5 \"\t\" \$9}'"
git config --global alias.pending '!f() { RED="\033[31m"; YELLOW="\033[33m"; GREEN="\033[32m"; RESET="\033[0m"; all=false; if [ "$1" = "-a" ]; then all=true; shift; fi; root="${1:-$PWD}"; find "$root" -type d -name ".git" -prune -print0 2>/dev/null | while IFS= read -r -d "" gitdir; do repo="${gitdir%/.git}"; status=$(git -C "$repo" status --porcelain 2>/dev/null); unpushed=$(git -C "$repo" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0); if [ -n "$status" ]; then color="$RED"; elif [ "$unpushed" -gt 0 ]; then color="$YELLOW"; elif [ "$all" = true ]; then color="$GREEN"; else continue; fi; relative="${repo#"$PWD"/}"; [ "$relative" = "$repo" ] && relative="$repo"; parent="${relative%/*}"; project="${relative##*/}"; if [ "$parent" = "$relative" ]; then printf "${color}%s${RESET}\n" "$project"; else printf "%s/${color}%s${RESET}\n" "$parent" "$project"; fi; done; }; f'

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

mkdir -p ~/.config/tig/
cp ./tig.config ~/.config/tig/config

git_activity_file=$(mktemp)
trap 'rm -f "$git_activity_file"' EXIT
wget --quiet --output-document="$git_activity_file" https://raw.githubusercontent.com/aaossa/git-activity/ac2ade9a49c202dfbd42c0e189692c5509bc710b/git-activity
echo "b6541cf893456230d78cb1c45277478eed39f9562e879ac66c742eea8fa58773  $git_activity_file" | sha256sum --check --status
mkdir -p ~/.local/bin/
cp "$git_activity_file" ~/.local/bin/git-activity
chmod +x ~/.local/bin/git-activity
