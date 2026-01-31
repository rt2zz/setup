#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
echo "REPO_ROOT: $REPO_ROOT"

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

# Install and load launchd agent
launchctl unload ~/Library/LaunchAgents/dev.zee.periodic.plist 2>/dev/null
cp "$REPO_ROOT/generated/dev.zee.periodic.plist" ~/Library/LaunchAgents/dev.zee.periodic.plist
launchctl load ~/Library/LaunchAgents/dev.zee.periodic.plist

# Bootstrap: generate initial icon
"$REPO_ROOT/mac/daily.sh"
### end daily script ###


### settings ###
# Copy .zshrc
cp "$REPO_ROOT/home/.zshrc" ~/.zshrc

# Copy Ghostty config
mkdir -p ~/Library/Application\ Support/com.mitchellh.ghostty
cp "$REPO_ROOT/home/Library/Application Support/com.mitchellh.ghostty/config" ~/Library/Application\ Support/com.mitchellh.ghostty/config

# Mac settings
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 500
defaults write com.apple.dock autohide-time-modifier -float 0
defaults write com.apple.dock mcx-expose-disabled -bool TRUE
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true
mkdir -p ~/Screenshots
defaults write com.apple.screencapture location ~/Screenshots
defaults write com.apple.finder QLEnableTextSelection -bool true
defaults write com.apple.finder AppleShowAllFiles YES
killall Finder
killall Dock
### end settings ###
