#! /usr/bin/env bash

set -e
set -x

# ── Clone repo if running via curl pipe ───────────────────────────────────────
DOTFILES_DIR="$HOME/.dotfiles"
if [ ! -f "./.zshrc" ]; then
  git clone https://github.com/ascariandrea/dotfiles -b master "$DOTFILES_DIR"
  cd "$DOTFILES_DIR"
fi

# ── Packages ──────────────────────────────────────────────────────────────────
sudo dnf install -y zsh tmux tmux-powerline powerline powerline-fonts vim curl git direnv zsh-syntax-highlighting

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
rm -rf ~/.oh-my-zsh
git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh

cp .zshrc ~/.zshrc

# ── tmux ──────────────────────────────────────────────────────────────────────
rm -rf ~/.tmux/plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
cp tmux.conf ~/.tmux.conf

# ── vim ───────────────────────────────────────────────────────────────────────
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
cp .vimrc ~/.vimrc

# ── git ───────────────────────────────────────────────────────────────────────
cp .gitignore_global ~/.gitignore_global
cp .gitconfig ~/.gitconfig

# delta (better git diff)
sudo dnf install -y git-delta

# ── config/ ───────────────────────────────────────────────────────────────────
mkdir -p ~/.config
cp -r config/k9s ~/.config/k9s

# ── Node (fnm) ────────────────────────────────────────────────────────────────
curl -fsSL https://fnm.vercel.app/install | bash

# ── pnpm ──────────────────────────────────────────────────────────────────────
curl -fsSL https://get.pnpm.io/install.sh | sh -

# ── bun ───────────────────────────────────────────────────────────────────────
curl -fsSL https://bun.sh/install | bash

# ── Change default shell ───────────────────────────────────────────────────────
sudo usermod -s $(which zsh) $USER

echo "Done. Open a new terminal or run: exec zsh"
