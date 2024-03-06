sudo pacman -S --needed --noconfirm fish

mkdir -p ~/.config/fish/functions/

cp /etc/pam.d/chsh ./chsh.backup
sudo cp ./chsh /etc/pam.d/
chsh -s /usr/bin/fish
sudo cp ./chsh.backup /etc/pam.d/chsh
rm ./chsh.backup

paru -S --needed --noconfirm autojump-rs

git clone https://github.com/oh-my-fish/oh-my-fish
cd ./oh-my-fish
./bin/install --offline --noninteractive
cd ..
rm -rf ./oh-my-fish

cp ./fish_prompt.fish ~/.config/fish/functions/
cp ./fish_variables ~/.config/fish/
cp ./config.fish ~/.config/fish/

# -r: Show escape symbols, e.g. colors
# -X: stops the screen from clearing when exiting
# https://unix.stackexchange.com/questions/19317/can-less-retain-colored-output
echo "export LESS=-Xr" >> ~/.profile

echo "export PASSWORD_STORE_SIGNING_KEY=6FB79D6D075A268571DE9E42C2C14B464D7B72E9" >> ~/.profile

echo "export RCLONE_PASSWORD_COMMAND=\"pass rclone/config\"" >> ~/.profile
