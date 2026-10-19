#!/bin/bash
# This Mac's sidecar reviewer (sync.sh registers it with `sidecar review
# reviewer`). sidecar runs it in a review's packet directory before anything
# publishes; see docs/review.md in the sidecar repo. Claude reads the packet
# with read-only tools and prints a verdict; this script turns it into the
# decision. UNSURE, or no clear verdict, leaves the review open for a person;
# the reason goes to reviewer.log in the packet.
set -uo pipefail

# The daemon runs under launchd, whose PATH lacks these.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:$PATH"

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

case "$verdict" in
  APPROVE) exec sidecar review approve "$SIDECAR_REVIEW_ID" ;;
  REJECT:*) exec sidecar review reject "$SIDECAR_REVIEW_ID" --reason "$(printf '%s' "${verdict#REJECT:}" | sed 's/^[[:space:]]*//')" ;;
  UNSURE:*) echo "$verdict"; exit 0 ;;
  *) echo "no verdict; left open"; exit 0 ;;
esac
