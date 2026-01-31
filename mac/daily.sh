#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ICONS_DIR="$REPO_ROOT/misc/ghostty-icons"
TARGET="$REPO_ROOT/generated/ghostty.icns"

icons=("$ICONS_DIR"/*.icns)
[[ ${#icons[@]} -eq 0 ]] && exit 1

random_icon="${icons[$((RANDOM % ${#icons[@]}))]}"
cp "$random_icon" "$TARGET"
