# Mac Setup Notes
- `setup.sh` installs launchd automation, runs the initial daily task, copies the bootstrap `.zshrc`, and then runs `sync.sh` (with `--yes` when setup.sh got `--yes`).
- `sync.sh` previews file and defaults changes before applying them.
- `sync.sh` copies managed app config and updates macOS defaults.
- `sync.sh` installs root-owned files from `../system` with `sudo`, only when they differ.
- `.zshrc` is intentionally excluded from `sync.sh` because installers append machine-specific shell config over time.

## Touch ID sudo
- `/etc/pam.d/sudo_local` adds `pam_tid.so`; it is included by `/etc/pam.d/sudo` on macOS 14+ and survives OS updates.
- Inside tmux/screen-style multiplexers Touch ID falls back to password unless `pam_reattach` is installed (`brew install pam-reattach`) and listed before `pam_tid.so` in `sudo_local`.

## Terminal Setup
- zsh with [zap](https://github.com/zap-zsh/zap) plugin manager
- See [../home](../home/) for config files

## Mac Settings
### UI Settings
- trackpad speed, scroll direction, Siri and Spotlight menu bar icons, and the menu bar
  clock (24-hour time only; `ShowDate` 2 = never) are managed by `sync.sh`
  defaults. macOS ignores a custom clock `DateFormat` now, so the clock's
  parts are the only knobs
- remaining manual steps: trackpad/mouse gestures not exposed via `defaults`,
  Control Center menu bar modules, disabling the Spotlight hotkey (Settings >
  Keyboard > Shortcuts > Spotlight)
- to discover a `defaults` key for a setting: `defaults read > /tmp/before`,
  change the setting in System Settings, `defaults read | diff /tmp/before -`

## Froggy (for the agent doing a new Mac)
Froggy itself is installed by Endofrog, not by `setup.sh`. Its settings are
per-Mac, so after it's installed and running, carry over these from the
previous Mac (ask Zack which one if it isn't obvious). **Quit Froggy on the
new Mac first** (`osascript -e 'quit app "Froggy"'`): it reads these at launch
and writes them back from memory, so a file copied under a running Froggy is
overwritten. Relaunch with `open -a Froggy` when done.

- **Snippets**: `~/Library/Application Support/Froggy/Snippets.json` (mode
  600). Strip entries with `"secure": true` first, e.g.
  `jq '.snippets |= map(select(.secure != true))'`. Their text lives in the old
  Mac's Keychain, not the file, so Zack has to re-create them by hand after
  setting the new Mac's Froggy PIN. Check: `froggy commands` lists a
  `snippet.saved.<id>` per snippet.
- **Extensions**: compare `ls ~/.froggy/extensions` on both Macs. Install
  ones from the bundled library with
  `/Applications/Froggy.app/Contents/MacOS/froggy-ext install <id>`
  (`froggy-ext library` lists them) rather than copying: library installs are
  symlinks into the app bundle. Copy only extensions that aren't in the
  library or that were customized.
- **Preferences** (`defaults read com.rt2zz.froggy`, Froggy quit): the
  hotkeys (`speechKey`, `ambientKey`, `keyboardHotkeyProfiles`,
  `additionalHotkeyBindings`) and the display toggles (`show*`,
  `hideMenuBarIcon`, `composerApps`, `fileSearchEnterAction`,
  `saveTranscribedUtterances`, `saveUtteranceAudio`).

Don't copy: the PIN (set it fresh with **Set PIN**), `froggyInstanceID`,
`diagnosticsDashboardToken`, `pairedMacs`, `remoteFroggyInstances`,
`preferredMicrophone`, the window positions (`*X`, `*Y`, `*Screen`), usage
history, `T3/session.json`, or the clipboard, history, transcripts, event
journal and agent checkpoints under `Application Support/Froggy`.
