#! /bin/zsh

set -e
set -x

## Requirements
# - zsh
# - prezto
# - tmux
# - powerline
# -- pip (brew install pip)
# --- python (brew install python)

rm -rf ~/.oh-my-zsh
git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
chsh -s /bin/zsh

curl https://raw.githubusercontent.com/caiogondim/bullet-train-oh-my-zsh-theme/master/bullet-train.zsh-theme  \
  --output ~/.oh-my-zsh/themes/bullet-train.zsh-theme
  ln -sf ~/.dotfiles/zshrc ~/.zshrc

rm -rf ~/.tmux/plugins;
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
ln -sf ~/.dotfiles/tmux.conf ~/.tmux.conf

# vim
## Install Vundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
## Install vim-plug
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# Vim colors solarized
cd ~/.vim/bundle;
rm -rf vim-colors-solarized;
git clone git://github.com/altercation/vim-colors-solarized.git;
mkdir -p ~/.vim/colors;
mv vim-colors-solarized/colors/solarized.vim ~/.vim/colors/;
rm -rf ~/.vim/bundle/vim-colors-solarized;

ln -sf ~/.dotfiles/vimrc ~/.vimrc

ln -sF ~/.dotfiles/config/ ~/.config
ln -sf ~/.dotfiles/gitconfig ~/.gitconfig

## BitBar
ln -sF ~/.dotfiles/bitbar/ ~/.bitbar
