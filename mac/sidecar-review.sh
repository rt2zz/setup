#!/bin/bash
# This Mac's sidecar reviewer (sync.sh registers it with `sidecar review
# reviewer`). sidecar runs it in a review's packet directory before anything
# publishes; see docs/review.md in the sidecar repo. Claude reads the packet
# with read-only tools and prints a verdict; this script turns it into the
# decision. No clear verdict leaves the review open for a person.
set -uo pipefail

# The daemon runs under launchd, whose PATH lacks these.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:/opt/homebrew/bin:$PATH"

reply=$(claude -p \
  --permission-mode default \
  --tools Read,Grep,Glob \
  --strict-mcp-config \
  --no-session-persistence \
  "$(cat "$SIDECAR_REVIEW_PROMPT")

You can read files but not run commands; this script records your decision.
Read diff.patch and every file listed under opaque/, then end your reply with
exactly one line: APPROVE, or REJECT: <file and what kind of content, without
repeating it>" </dev/null) || exit 1

# Last non-empty line, without markdown emphasis or surrounding whitespace.
verdict=$(printf '%s\n' "$reply" | sed -e 's/[*`]//g' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | tail -n 1)

case "$verdict" in
  APPROVE) exec sidecar review approve "$SIDECAR_REVIEW_ID" ;;
  REJECT:*) exec sidecar review reject "$SIDECAR_REVIEW_ID" --reason "$(printf '%s' "${verdict#REJECT:}" | sed 's/^[[:space:]]*//')" ;;
  *) exit 0 ;;
esac
