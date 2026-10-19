#!/bin/bash
# This Mac's sidecar reviewer (sync.sh registers it with `sidecar review
# reviewer`). sidecar runs it in a review's packet directory before anything
# publishes; see docs/review.md in the sidecar repo. Claude reads the packet
# with read-only tools and prints a verdict; this script turns it into the
# decision. REJECT, UNSURE, or no clear verdict also starts a T3 thread on fox
# to resolve it with a person; UNSURE and no verdict leave the review open.
set -uo pipefail

# The daemon runs under launchd, whose PATH lacks these.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:$PATH"

# A curl config holding the T3 webhook's URL. The URL is the credential, so
# the file is machine-local and private, never in this repo.
webhook_config="$HOME/.config/setup/sidecar-review-webhook"

# notify <verdict> <reason>: start the T3 thread. A failure is logged, never
# fatal: the review's state already says it needs a person.
notify() {
  if [[ ! -r "$webhook_config" ]]; then
    echo "no $webhook_config; no T3 thread started"
    return 0
  fi
  jq -n --arg review "$SIDECAR_REVIEW_ID" --arg verdict "$1" --arg reason "$2" \
    --arg machine "$(id -un)@$(hostname -s)" \
    '{review: $review, verdict: $verdict, reason: $reason, machine: $machine}' |
    curl -fsS --max-time 30 -K "$webhook_config" -X POST \
      -H 'Content-Type: application/json' --data-binary @- >/dev/null ||
    echo "T3 webhook failed; no thread started"
}

reply=$(claude -p \
  --permission-mode default \
  --tools Read,Grep,Glob \
  --strict-mcp-config \
  --no-session-persistence \
  --effort medium \
  "$(cat "$SIDECAR_REVIEW_PROMPT")

Keep this brief: you are only screening for sensitive content, so skim the
change for it and decide. Don't analyze what the change does or whether it's
right.

You can read files but not run commands; this script records your decision.
Read diff.patch and every file listed under opaque/, then end your reply with
exactly one line:

APPROVE
REJECT: <file and what kind of content>
UNSURE: <file and what a person should check>

Never repeat the sensitive value itself in a REJECT or UNSURE line." </dev/null) || exit 1

# Last non-empty line, without markdown emphasis or surrounding whitespace.
verdict=$(printf '%s\n' "$reply" | sed -e 's/[*`]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | tail -n 1)
reason=$(printf '%s' "${verdict#*:}" | sed 's/^[[:space:]]*//')

case "$verdict" in
  APPROVE)
    exec sidecar review approve "$SIDECAR_REVIEW_ID"
    ;;
  REJECT:*)
    sidecar review reject "$SIDECAR_REVIEW_ID" --reason "$reason"
    status=$?
    notify rejected "$reason"
    exit "$status"
    ;;
  UNSURE:*)
    echo "$verdict"
    notify unsure "$reason"
    ;;
  *)
    echo "no verdict; left open"
    notify unsure "the reviewer gave no clear verdict"
    ;;
esac
