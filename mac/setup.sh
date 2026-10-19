#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=mac/lib.sh
source "$SCRIPT_DIR/lib.sh"

ASSUME_YES=0

usage() {
  cat <<EOF
Usage: $0 [--yes]

First-time machine setup. Prompts before each optional or destructive step.

Options:
  --yes       Run non-interactively, answering yes to every prompt. Note this
              overwrites a diverged ~/.zshrc (a timestamped backup is always
              created first).
  -h, --help  Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      ASSUME_YES=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

mkdir -p "$REPO_ROOT/generated"

header "launchd daily task"
# Generate plist with current user's home directory
cat > "$REPO_ROOT/generated/dev.zee.periodic.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.zee.periodic</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REPO_ROOT/mac/daily.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>3600</integer>
</dict>
</plist>
EOF

chmod +x "$REPO_ROOT/mac/daily.sh"
chmod +x "$REPO_ROOT/mac/sync.sh"

mkdir -p "$HOME/Library/LaunchAgents"
launchctl unload "$HOME/Library/LaunchAgents/dev.zee.periodic.plist" 2>/dev/null || true
cp "$REPO_ROOT/generated/dev.zee.periodic.plist" "$HOME/Library/LaunchAgents/dev.zee.periodic.plist"
launchctl load "$HOME/Library/LaunchAgents/dev.zee.periodic.plist"

# Bootstrap: generate initial icon
"$REPO_ROOT/mac/daily.sh"
ok "dev.zee.periodic agent installed and loaded"

header "ssh"
# Ensure ~/.ssh/config includes the shared config synced by sync.sh. The
# Include goes at the bottom so machine-specific entries above it win: ssh
# applies every matching Host block, first value per option wins.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if grep -qxF 'Include ~/.ssh/config.d/shared' "$HOME/.ssh/config" 2>/dev/null; then
  skip "~/.ssh/config already includes the shared config"
else
  printf '\nInclude ~/.ssh/config.d/shared\n' >> "$HOME/.ssh/config"
  chmod 600 "$HOME/.ssh/config"
  ok "Added shared Include to ~/.ssh/config"
fi

header "shell config"
# Bootstrap ~/.zshrc from the repo. Intentionally not in sync.sh because other
# installers append machine-specific sections to ~/.zshrc over time — so
# overwriting is destructive and requires confirmation (plus a backup).
if [[ ! -f "$HOME/.zshrc" ]]; then
  cp "$REPO_ROOT/home/.zshrc" "$HOME/.zshrc"
  ok "Created ~/.zshrc from repo bootstrap copy"
elif cmp -s "$REPO_ROOT/home/.zshrc" "$HOME/.zshrc"; then
  skip "~/.zshrc matches the repo bootstrap copy"
else
  warn "~/.zshrc differs from the repo bootstrap copy:"
  diff -u "$HOME/.zshrc" "$REPO_ROOT/home/.zshrc" | redact_sensitive_diff || true
  if confirm "Overwrite ~/.zshrc with the repo copy? A backup will be created." y; then
    zshrc_backup="$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
    cp "$HOME/.zshrc" "$zshrc_backup"
    cp "$REPO_ROOT/home/.zshrc" "$HOME/.zshrc"
    ok "Overwrote ~/.zshrc (backup at $zshrc_backup)"
  else
    skip "Keeping existing ~/.zshrc"
  fi
fi

header "tools"
# Everything home/.zshrc_base assumes exists. Each is additive, so the
# prompts default to yes.
if command -v fnm &>/dev/null; then
  skip "fnm already installed"
elif confirm "Install fnm (Fast Node Manager)?" y; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
  ok "fnm installed"
fi
# --skip-shell leaves activation to us; without it there is no node on PATH.
# Only when fnm exists, or every new shell would fail on it.
if grep -qF 'fnm env' "$HOME/.zshrc"; then
  skip "fnm already activated in ~/.zshrc"
elif ! command -v fnm &>/dev/null; then
  skip "fnm not installed; not activating it in ~/.zshrc"
else
  # shellcheck disable=SC2016 # literal $(...) written into ~/.zshrc
  printf '\n# fnm\neval "$(fnm env --use-on-cd --shell zsh)"\n' >> "$HOME/.zshrc"
  ok "Added fnm activation to ~/.zshrc"
fi

if [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ]]; then
  skip "zap already installed"
elif confirm "Install zap (zsh plugin manager)?" y; then
  # --keep prevents zap's installer from replacing ~/.zshrc. Fetch first: a
  # failed curl inside <(...) is invisible to set -e, and zsh then runs nothing.
  zap_installer="$(curl -fsSL https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh)"
  zsh -c "$zap_installer" zap-install --branch release-v1 --keep
  [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ]] || { warn "zap install did not produce zap.zsh"; exit 1; }
  ok "zap installed"
fi

if command -v bun &>/dev/null || [[ -x "$HOME/.bun/bin/bun" ]]; then
  skip "bun already installed"
elif confirm "Install bun?" y; then
  curl -fsSL https://bun.sh/install | bash
  ok "bun installed"
fi

if command -v zoxide &>/dev/null || [[ -x "$HOME/.local/bin/zoxide" ]]; then
  skip "zoxide already installed"
elif confirm "Install zoxide?" y; then
  # Installs to ~/.local/bin, which home/.profile puts on PATH.
  curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  ok "zoxide installed"
fi

if [[ "$ASSUME_YES" -eq 1 ]]; then
  "$REPO_ROOT/mac/sync.sh" --yes
else
  "$REPO_ROOT/mac/sync.sh"
fi

warn "Log out and back in: key repeat and the other keyboard settings only take effect at login."
