# Mac Setup Notes

## Terminal Setup
- zsh with [zap](https://github.com/zap-zsh/zap) plugin manager
- See [~/home](../home/) for config files

## Mac Settings
### UI Settings
- update various trackpack and mouse gestures
- reduce menu bar clutter

### Terminal Settings
```bash
# hide dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 500
defaults write com.apple.dock autohide-time-modifier -float 0

# disable expose
defaults write com.apple.dock mcx-expose-disabled -bool TRUE

# faster key repeat
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# instant window animations (note: these might not do anything nowadays)
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true

# save screenshots to ~/Screenshots
mkdir ~/Screenshots
defaults write com.apple.screencapture location ~/Screenshots

# allow text selection in quick look
defaults write com.apple.finder QLEnableTextSelection -bool true

# misc (show hidden files)
defaults write com.apple.finder AppleShowAllFiles YES; 

# apply all
killall Finder
killall Dock
```

