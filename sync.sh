#!/bin/bash
git add -A
git commit -m "auto-commit $(date +"%Y-%m-%d %H:%M:%S")"

# Try to push and capture the exit status
if ! git push origin/test main; then
    echo "Push failed, attempting to show notification..."
    osascript -e 'display alert "Repo Sync Failed" message "Please check directory: $(pwd)"'

    # Try to show notification and capture any errors
    # if ! osascript -e 'display notification "Repo sync failed" with title "Error"'; then
    #     echo "Failed to show notification"
    # else
    #     echo "Notification should have been shown"
    # fi
fi

osascript -e 'display alert "Hello CEO" message "Your automatic Git push was successful!"'
