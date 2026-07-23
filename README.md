# setup

## New machine

```
git clone https://github.com/rt2zz/setup.git ~/dev/setup
cd ~/dev/setup && ./mac/setup.sh
```

Then sign into Tailscale and iCloud. setup.sh prompts before each optional or
destructive step (all prompts default to yes); pass `--yes` to run
non-interactively.

## mac

First-time setup (interactive; `--yes` takes the default answer for every
prompt):

`./mac/setup.sh`

Preview and confirm idempotent settings/config sync:

`./mac/sync.sh`

Preview only:

`./mac/sync.sh --dry-run`

Apply without prompting:

`./mac/sync.sh --yes`

Raycast is managed through curated preferences only. App-support databases,
caches, telemetry files, and account/device-specific state are intentionally
excluded.

`~/.zshrc` is bootstrapped by setup.sh and intentionally excluded from sync.sh
because other installers append machine-specific shell config over time. If
`~/.zshrc` already exists and differs, setup.sh shows a diff and asks before
overwriting; a timestamped backup is always created first.

`~/.gitconfig` and `~/.config/jj/config.toml` are synced from `home/`.

Shared SSH config lives in `home/.ssh/config.d/shared` and is synced to
`~/.ssh/config.d/shared`. First-time setup appends an
`Include ~/.ssh/config.d/shared` line to `~/.ssh/config`. Machine-specific
host entries go above the Include; ssh uses the first value it finds per
option, so local entries override shared ones.
