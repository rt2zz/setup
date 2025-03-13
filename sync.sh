#!/bin/bash
git add -A
git commit -m "auto-commit $(date +"%Y-%m-%d %H:%M:%S")"
if ! git push origin/test main; then
    osascript -e 'display notification "Repo sync failed" with title "Error"'
fi
