#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

mkdir -p "$REPO_ROOT/generated"

### daily script ###
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

# Make daily.sh executable
chmod +x "$REPO_ROOT/mac/daily.sh"
chmod +x "$REPO_ROOT/mac/sync.sh"

# Install and load launchd agent
mkdir -p "$HOME/Library/LaunchAgents"
launchctl unload "$HOME/Library/LaunchAgents/dev.zee.periodic.plist" 2>/dev/null || true
cp "$REPO_ROOT/generated/dev.zee.periodic.plist" "$HOME/Library/LaunchAgents/dev.zee.periodic.plist"
launchctl load "$HOME/Library/LaunchAgents/dev.zee.periodic.plist"

# Bootstrap: generate initial icon
"$REPO_ROOT/mac/daily.sh"
### end daily script ###

# Bootstrap shell config. This is intentionally not in sync.sh because other
# installers append machine-specific sections to ~/.zshrc.
cp "$REPO_ROOT/home/.zshrc" "$HOME/.zshrc"

### tools ###
# Install fnm (Fast Node Manager)
if ! command -v fnm &>/dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
fi
### end tools ###

"$REPO_ROOT/mac/sync.sh" --yes
