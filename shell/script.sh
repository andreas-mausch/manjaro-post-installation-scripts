sudo pacman -S --needed --noconfirm fish

mkdir -p ~/.config/fish/functions/

cp /etc/pam.d/chsh ./chsh.backup
sudo cp ./chsh /etc/pam.d/
chsh -s /usr/bin/fish
sudo cp ./chsh.backup /etc/pam.d/chsh
rm ./chsh.backup

paru -S --needed --noconfirm autojump-git

git clone https://github.com/oh-my-fish/oh-my-fish
cd ./oh-my-fish
./bin/install --offline --noninteractive
cd ..
rm -rf ./oh-my-fish

cp ./fish_prompt.fish ~/.config/fish/functions/
cp ./fish_variables ~/.config/fish/
cp ./config.fish ~/.config/fish/
