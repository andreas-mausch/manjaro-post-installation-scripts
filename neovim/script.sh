sudo pacman -S --needed --noconfirm neovim ripgrep trash-cli ttf-sourcecodepro-nerd

mkdir -p ~/.config/nvim
git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim

cp --recursive ./user ~/.config/nvim/lua/

nvim  --headless -c 'quitall'
