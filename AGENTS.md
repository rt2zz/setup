# setup

Machine setup for Zack's Macs: `mac/setup.sh` for first-time setup,
`mac/sync.sh` for idempotent config and defaults. See README.md.

## This repo syncs itself — never commit, never push

setup is a sidecar-managed standalone repo (`.sidecar` with `path = "."`). A
daemon snapshots your edits to a per-machine inbox branch and merges them into
`main` for you. Saving a file is the whole job.

- Do not run `git commit`, `git push`, `git pull`, `git rebase`, `git reset`,
  `git clean`, or switch branches. Read-only git (log, diff, show) is fine.
- The checkout lives on a `sidecar-inbox/*` branch, not `main`. That is
  expected; don't "fix" it.
- `sidecar status` shows the last sync; `sidecar sync` forces one now.

Edits reach every Mac and get run there (`mac/daily.sh` runs hourly from this
checkout), so don't leave a script half-edited.

Never write a token, key, or password into this repo. Redaction (`secrets`)
strips known credential formats on push; that is a backstop, not permission.
Use environment variable names instead of values.
