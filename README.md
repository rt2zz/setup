## mac

First-time setup:

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

`~/.zshrc` is copied only during first-time setup because other installers
append machine-specific shell config over time.
