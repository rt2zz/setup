# Tools installed by mac/setup.sh (zap, zoxide) live in ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

alias devices='xcrun xctrace list devices'
alias ipme='ipconfig getifaddr en0'

export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1
# Claude Code uses the claude.ai login on these Macs, never an API key: a key
# in the environment overrides the login and bills the API account instead.
unset ANTHROPIC_API_KEY
