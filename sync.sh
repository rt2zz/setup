#!/bin/bash
git add -A
git commit -m "auto-commit $(date +"%Y-%m-%d %H:%M:%S")"

# Try to push and capture the exit status
if ! git push origin main; then
    echo "Push failed, attempting to show notification..."
    osascript -e "display alert \"Repo Sync Failed\" message \"Please check directory: $(pwd)\""
fi

