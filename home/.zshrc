# NOTES
# This file needs to be copied or symlinked to ~/.zshrc
# This file assumes the rt2zz/setup repo exists at ~/dev/setup
# This setup assumes you will install nvm, bun, and zoxide
# and those and other install scripts will append updates to this file

# --- Zap Plugin Manager ---
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zap-zsh/zap-prompt"
plug "rkh/zsh-jj"
plug "zsh-users/zsh-syntax-highlighting"
plug "rt2zz/degit"

# --- Completion System ---
autoload -Uz compinit
compinit

# --- Personal Customizations ---
source ~/dev/setup/home/.zshrc_mods
source ~/dev/setup/home/.profile

# Section where managed machine-specific config typically goes
# --- nvm ---
# --- bun ---
# --- zoxide ---
