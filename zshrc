# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="bullet-train"

BULLETTRAIN_DIR_EXTENDED=0

plugins=(git ssh-agent)

source $ZSH/oh-my-zsh.sh

# ALIASES

alias g='git'
alias gc='git commit'
alias gco='git checkout'
alias gpush='git push'
alias grbb='git rebase -i HEAD~$(git rev-list HEAD --count)'
alias tmux-attach='tmux attach-session -t 0'

# F**k all the things
eval "$(thefuck --alias)"

# PATH

# GO
export PATH=$PATH:/usr/local/opt/go/libexec/bin

# NVM
export NVM_DIR="$HOME/.nvm"
. "/usr/local/opt/nvm/nvm.sh"

# POWERLINE
export PATH=$PATH:/usrl/local/lib/python2.7/site-packages/powerline

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# added by travis gem
[ -f /Users/andreaascari/.travis/travis.sh ] && source /Users/andreaascari/.travis/travis.sh
