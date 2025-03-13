#!/bin/bash
git add -A
git commit -m "auto-commit $(date +"%Y-%m-%d %H:%M:%S")"

# Try to push and capture the exit status
if ! git push origin/test main; then
    echo "Push failed, attempting to show notification..."
    osascript -e 'display alert "Repo sync failed" with title "Error"'
fi
