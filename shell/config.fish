begin
    set --local AUTOJUMP_PATH /usr/share/autojump/autojump.fish
    if test -e $AUTOJUMP_PATH
        source $AUTOJUMP_PATH
    end
end

alias clip="xclip -selection clipboard -rmlastnl"
alias top="zenith"
alias lg="lazygit"
alias crt="cool-retro-term --profile \"Green Scanlines\" --fullscreen"
