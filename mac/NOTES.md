# Mac Setup Notes
- `setup.sh` installs launchd automation, runs the initial daily task, copies the bootstrap `.zshrc`, and invokes `sync.sh --yes`.
- `sync.sh` previews file and defaults changes before applying them.
- `sync.sh` copies managed app config, updates macOS defaults, and applies curated Raycast preferences.
- `.zshrc` is intentionally excluded from `sync.sh` because installers append machine-specific shell config over time.

## Terminal Setup
- zsh with [zap](https://github.com/zap-zsh/zap) plugin manager
- See [../home](../home/) for config files

## Mac Settings
### UI Settings
- update various trackpack and mouse gestures
- reduce menu bar clutter

## Raycast Settings
- managed through curated `defaults` values only
- app-support databases, caches, telemetry files, and account/device-specific state are intentionally excluded
