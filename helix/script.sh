sudo pacman -S --needed --noconfirm helix
sudo pacman -S --needed --noconfirm vscode-json-languageserver
sudo pacman -S --needed --noconfirm yaml-language-server
sudo pacman -S --needed --noconfirm tombi # TOML
sudo pacman -S --needed --noconfirm marksman # Markdown
sudo pacman -S --needed --noconfirm vscode-css-languageserver
sudo pacman -S --needed --noconfirm dockerfile-language-server
sudo pacman -S --needed --noconfirm typescript-language-server
sudo pacman -S --needed --noconfirm vue-language-server
sudo pacman -S --needed --noconfirm eslint-language-server
sudo pacman -S --needed --noconfirm bash-language-server
sudo pacman -S --needed --noconfirm rust-analyzer

paru -S --needed --noconfirm nodejs-compose-language-service
paru -S --needed --noconfirm jdtls
paru -S --needed --noconfirm kotlin-language-server-bin
paru -S --needed --noconfirm ansible-language-server

mkdir -p ~/.config/helix/
cp ./config.toml ~/.config/helix/
