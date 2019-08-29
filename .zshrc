# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# locale
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

ZSH_THEME="bullet-train"

BULLETTRAIN_DIR_EXTENDED=0

plugins=(docker git)

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

# BREW
export PATH=/usr/local/sbin:$PATH
# GO
export PATH=$PATH:/usr/local/opt/go/libexec/bin

# POWERLINE
export PATH=$PATH:/usrl/local/lib/python2.7/site-packages/powerline

# export ANDROID_HOME=${HOME}/Library/Android/sdk
# export PATH=${PATH}:${ANDROID_HOME}/emulator
# export PATH=${PATH}:${ANDROID_HOME}/tools
# export PATH=${PATH}:${ANDROID_HOME}/platform-tools

# # JAVA
# export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
# export PATH=$PATH:$JAVA_HOME/bin

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# added by travis gem
[ -f /Users/andreaascari/.travis/travis.sh ] && source /Users/andreaascari/.travis/travis.sh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
