# setup

## New machine

```
git clone https://github.com/rt2zz/setup.git ~/dev/setup
cd ~/dev/setup && ./mac/setup.sh
```

Then sign into Tailscale and iCloud, and log out and back in: key repeat and
the typing settings only take effect at login. Agents setting up a Mac: also see the
Froggy section of [mac/NOTES.md](mac/NOTES.md). setup.sh prompts before each optional or
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

`~/.zshrc` is bootstrapped by setup.sh and intentionally excluded from sync.sh
because other installers append machine-specific shell config over time. If
`~/.zshrc` already exists and differs, setup.sh shows a diff and asks before
overwriting; a timestamped backup is always created first.

Shared git and jj config follow the same rule: sync owns a file the tool reads
but doesn't write to by default. `~/.gitconfig` and `~/.config/jj/config.toml`
are machine-local and never synced, since `git config --global`,
`gh auth setup-git` and `jj config set --user` write there.

- git: `home/.config/git/config` is synced to `~/.config/git/config`. git reads
  it before `~/.gitconfig`, so local values win (a Mac can keep its own commit
  identity). `sync.sh` creates an empty `~/.gitconfig` if there is none, because
  without it `git config --global` would write into the synced file.
- jj: `home/.config/jj/conf.d/shared.toml` is synced to
  `~/.config/jj/conf.d/shared.toml`. jj reads `conf.d/` *after* `config.toml`,
  so shared values win there. To override one on a Mac, put it in
  `~/.config/jj/conf.d/zz-local.toml`, which loads later.

Shared SSH config lives in `home/.ssh/config.d/shared` and is synced to
`~/.ssh/config.d/shared`. First-time setup appends an
`Include ~/.ssh/config.d/shared` line to `~/.ssh/config`. Machine-specific
host entries go above the Include; ssh uses the first value it finds per
option, so local entries override shared ones.

Touch ID for `sudo` is enabled by syncing `system/etc/pam.d/sudo_local` to
`/etc/pam.d/sudo_local` (macOS 14+). Unlike `/etc/pam.d/sudo`, this file survives
macOS updates. `sync.sh` only asks for your password when the file differs.

## Publish review

This repo is public and syncs itself, so sidecar can hold each change for a
review before it leaves the Mac (`review = "required"` in `.sidecar`). The
reviewer is `mac/sidecar-review.sh`: Claude reads the change with read-only
tools against the guidance in `.sidecar-review` and approves or rejects it.
`sync.sh` registers it with `sidecar review reviewer` once the installed
sidecar supports review. Every Mac syncing this repo needs that sidecar before
the policy goes on, because older versions ignore it and push as usual.
`sidecar review` lists reviews; `sidecar review approve|reject <id>` decides
one by hand.
