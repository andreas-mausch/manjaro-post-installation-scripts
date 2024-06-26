sudo pacman -S --needed --noconfirm code

code --install-extension EditorConfig.EditorConfig
code --install-extension dbaeumer.vscode-eslint
code --install-extension eamodio.gitlens
code --install-extension Vue.volar
code --install-extension stylelint.vscode-stylelint
code --install-extension patbenatar.advanced-new-file
code --install-extension rangav.vscode-thunder-client
code --install-extension jebbs.plantuml

mkdir -p ~/.config/Code\ -\ OSS/User/
cp ./settings.json ~/.config/Code\ -\ OSS/User/

# TODO:
# Make VSCode not use Gnome Keyring:
# in /home/neonew/.vscode-oss/argv.json set
# "password-store": "basic"
