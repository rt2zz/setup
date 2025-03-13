#!/bin/bash
git add -A
git commit -m "auto-commit on wake/start at $(date +"%Y-%m-%d %H:%M:%S")"
git push origin main
