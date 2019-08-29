#! /bin/zsh

set -e
set -x

set package_manager = $(brew)

## Requirements

# zsh
$package_manager zsh
# on-my-zsh
rm -rf ~/.oh-my-zsh
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
# zsh - bullet train theme
curl https://raw.githubusercontent.com/caiogondim/bullet-train-oh-my-zsh-theme/master/bullet-train.zsh-theme  \
  --output ~/.oh-my-zsh/themes/bullet-train.zsh-theme
# copy .zshrc
cp .zshrc ~/.zshrc
# zsh - docker autocompletion
mkdir -p ~/.oh-my-zsh/plugins/docker/
curl -fLo ~/.oh-my-zsh/plugins/docker/_docker https://raw.github.com/felixr/docker-zsh-completion/master/_docker
# thefuck
$package_manager thefuck
# tmux
$package_manager tmux
# - python
$package_manager install python@2
# - pip 
$package_manager install pip
# - powerline
pip install powerline-status
# - powerline fonts
git clone https://github.com/powerline/fonts.git --depth=1

# tmux plugins
rm -rf ~/.tmux/plugins;
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# copy tmux.conf
cp ./tmux.conf ~/.tmux.conf

# vim
## Vundle
rm -rf ~/.vim/bundle/Vundle.vim
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
## Install vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# Vim colors solarized
rm -rf ~/.vim/bundle/vim-colors-solarized
git clone git://github.com/altercation/vim-colors-solarized.git ~/.vim/colors/
# copy .vmrc
cp ./.vimrc ~/.vimrc
# copy .gitignore_global 
cp .gitignore_global ~/.gitignore_global
# copy .gitconfig
cp .gitconfig ~/.gitconfig
# copy .config
cp -r .config ~/.config


## BitBar
cp -r ./bitbar ~/.bitbar
