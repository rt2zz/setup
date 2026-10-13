# NOTES
# This file needs to be copied or symlinked to ~/.zshrc
# This file assumes the rt2zz/setup repo exists at ~/dev/setup
# This setup assumes you will install fnm, bun, and zoxide
# and those and other install scripts will append updates to this file


# --- Personal Customizations ---
# .profile first: it puts ~/.local/bin (zoxide) on PATH, which .zshrc_base needs
source "$HOME/dev/setup/home/.profile"
source "$HOME/dev/setup/home/.zshrc_base"
source "$HOME/dev/setup/home/.zshrc_mods"

# Section where managed machine-specific config typically goes
# --- bun ---
# --- zoxide ---
