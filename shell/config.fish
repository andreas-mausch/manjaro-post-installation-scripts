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
alias crt="cool-retro-term --profile \"Green Scanlines Blinking Cursor\" --fullscreen"

function scana4; if test -e scan.jpg; echo 'File \'scan.jpg\' already exists, aborting.'; return 1; else; scanimage --device-name 'hpaio:/usb/OfficeJet_Pro_6970?serial=THXXXXXXX' --progress --format tiff --mode Color --resolution 300dpi -l 0mm -t 0mm -x 210mm -y 297mm | magick - $argv -resize '1920x1920>' -quality 75 scan.jpg; end; end
