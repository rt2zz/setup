# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zap-zsh/zap-prompt"
plug "rkh/zsh-jj"
plug "zsh-users/zsh-syntax-highlighting"

# Personal modifications (jj prompt customization, etc.)
source ~/.zshrc_mods

# Load and initialise completion system
autoload -Uz compinit
compinit

# bun completions
[ -s "/Users/zachary.story/.bun/_bun" ] && source "/Users/zachary.story/.bun/_bun"

# Source profile for common aliases and such
source ~/.profile

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
