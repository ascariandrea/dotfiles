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

# ── Agent skills (opencode + Claude Code) ─────────────────────────────────────
# Symlinked, not copied, so edits land in this repo. opencode dir is canonical;
# ~/.claude/skills points at it. A pre-existing real dir is moved to a backup
# outside the skills dirs (a backup left inside would load as a duplicate skill).
mkdir -p ~/.config/opencode/skills ~/.claude/skills
SKILLS_BACKUP=~/.local/state/dotfiles-backup/skills-$(date +%Y%m%d%H%M%S)
for s in "$PWD"/agents/skills/*/; do
  n=$(basename "$s")
  for pair in opencode:"$HOME/.config/opencode/skills/$n" claude:"$HOME/.claude/skills/$n"; do
    tool=${pair%%:*} dst=${pair#*:}
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      mkdir -p "$SKILLS_BACKUP/$tool" && mv "$dst" "$SKILLS_BACKUP/$tool/"
    fi
  done
  ln -sfn "${s%/}" ~/.config/opencode/skills/"$n"
  ln -sfn ../../.config/opencode/skills/"$n" ~/.claude/skills/"$n"
done

# Per-machine values + secrets for the skills (never committed)
if [ ! -f ~/.env ]; then cp env.example ~/.env; chmod 600 ~/.env; echo "Fill in ~/.env"; fi

# ── Node (fnm) ────────────────────────────────────────────────────────────────
curl -fsSL https://fnm.vercel.app/install | bash

# ── pnpm ──────────────────────────────────────────────────────────────────────
curl -fsSL https://get.pnpm.io/install.sh | sh -

# ── bun ───────────────────────────────────────────────────────────────────────
curl -fsSL https://bun.sh/install | bash

# ── Change default shell ───────────────────────────────────────────────────────
sudo usermod -s $(which zsh) $USER

echo "Done. Open a new terminal or run: exec zsh"
