#!/bin/bash
git add -A
git commit -m "auto-commit $(date +"%Y-%m-%d %H:%M:%S")"

# Try to push and capture the exit status
if ! git push origin/test main; then
    echo "Push failed, attempting to show notification..."
    osascript -e 'display notification "Repo sync failed (git push to origin)" with message "Repo Sync Failed"'

    # Try to show notification and capture any errors
    # if ! osascript -e 'display notification "Repo sync failed" with title "Error"'; then
    #     echo "Failed to show notification"
    # else
    #     echo "Notification should have been shown"
    # fi
fi
