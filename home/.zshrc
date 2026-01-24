# --- Zap Plugin Manager ---
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zap-zsh/zap-prompt"
plug "rkh/zsh-jj"
plug "zsh-users/zsh-syntax-highlighting"

# --- Completion System ---
autoload -Uz compinit
compinit

# --- Tools ---
eval "$(zoxide init zsh)"

# --- Keybindings ---
bindkey '^ ' autosuggest-execute

# --- Personal Customizations ---
source ~/.zshrc_mods
source ~/.profile

# --- nvm ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# --- bun ---
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
