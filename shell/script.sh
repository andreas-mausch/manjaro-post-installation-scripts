sudo pacman -S --needed --noconfirm fish

mkdir -p ~/.config/fish/functions/

sudo chsh -s /usr/bin/fish "$USER"

paru -S --needed --noconfirm autojump-rs

git clone https://github.com/oh-my-fish/oh-my-fish
cd ./oh-my-fish
./bin/install --offline --noninteractive
cd ..
rm -rf ./oh-my-fish

cp ./fish_prompt.fish ~/.config/fish/functions/
cp ./fish_variables ~/.config/fish/
cp ./config.fish ~/.config/fish/

append_once() {
  grep -qxF "$1" "$2" 2>/dev/null || echo "$1" >> "$2"
}

# -r: Show escape symbols, e.g. colors
# -X: stops the screen from clearing when exiting
# https://unix.stackexchange.com/questions/19317/can-less-retain-colored-output
append_once 'export LESS=-Xr' ~/.profile

append_once 'export PASSWORD_STORE_SIGNING_KEY=6FB79D6D075A268571DE9E42C2C14B464D7B72E9' ~/.profile

append_once 'export RCLONE_PASSWORD_COMMAND="pass rclone/config"' ~/.profile

# https://github.com/ollama/ollama/pull/4508
append_once 'export OLLAMA_NOHISTORY=1' ~/.profile
