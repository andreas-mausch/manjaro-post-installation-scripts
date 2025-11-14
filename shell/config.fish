begin
  set --local AUTOJUMP_PATH /usr/share/autojump/autojump.fish
  if test -e $AUTOJUMP_PATH
    source $AUTOJUMP_PATH
  end
end

set -gx EDITOR helix

alias clip="xclip -selection clipboard -rmlastnl"
alias top="zenith"
alias lg="lazygit"
alias ip="ip --color=auto"
alias crt="cool-retro-term --profile \"Green Scanlines Blinking Cursor\" --fullscreen"

function git-bundle-remote
  mkdir -p /tmp/gitbundlerepo
  and git clone --mirror $argv /tmp/gitbundlerepo
  and git -C /tmp/gitbundlerepo bundle create "$(pwd)/$(date --iso-8601)_$(basename -s .git $(git -C /tmp/gitbundlerepo remote get-url origin)).git.bundle" --all
  and rm -rf /tmp/gitbundlerepo
end

function scana4
  if test -e scan.jpg
    echo 'File \'scan.jpg\' already exists, aborting.'
    return 1
  else
    scanimage --device-name 'hpaio:/usb/OfficeJet_Pro_6970?serial=THXXXXXXX' --progress --format tiff --mode Color --resolution 300dpi -l 0mm -t 0mm -x 210mm -y 297mm | magick - $argv -resize '1920x1920>' -quality 75 scan.jpg
  end
end

# Example call:
# generate-password --length=16
function generate-password -a length
  argparse 'l/length=' -- $argv || return

  set -l length 12
  set -ql _flag_length[1]
  and set length $_flag_length[-1]

  # Generates a random password with the base58 alphabet
  cat /dev/random | tr -dc '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz' | head -c $length | sed -r 's/(.{4})/\1-/g' | sed -r 's/(.*)-$/\1\n/g'
end
