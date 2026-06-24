#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ASSUME_YES=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [--yes] [--dry-run]

Preview and sync idempotent setup files and settings.

Options:
  --yes       Apply after printing the preview, without prompting.
  --dry-run   Print the preview and exit without applying.
  -h, --help  Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      ASSUME_YES=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$ASSUME_YES" -eq 1 && "$DRY_RUN" -eq 1 ]]; then
  echo "Cannot combine --yes and --dry-run." >&2
  exit 2
fi

file_sources=(
  "$REPO_ROOT/home/Library/Application Support/com.mitchellh.ghostty/config"
)
file_destinations=(
  "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
)

directories=(
  "$HOME/Screenshots"
  "$HOME/Library/Application Support/com.mitchellh.ghostty"
)

mac_defaults=(
  "com.apple.dock|autohide|bool|true"
  "com.apple.dock|autohide-delay|float|500"
  "com.apple.dock|autohide-time-modifier|float|0"
  "com.apple.dock|mcx-expose-disabled|bool|true"
  "NSGlobalDomain|KeyRepeat|int|1"
  "NSGlobalDomain|InitialKeyRepeat|int|10"
  "NSGlobalDomain|NSWindowResizeTime|float|0.001"
  "com.apple.dock|expose-animation-duration|float|0.1"
  "com.apple.finder|DisableAllAnimations|bool|true"
  "com.apple.screencapture|location|string|$HOME/Screenshots"
  "com.apple.finder|QLEnableTextSelection|bool|true"
  "com.apple.finder|AppleShowAllFiles|bool|true"
)

raycast_defaults=(
  "com.raycast.macos|raycastGlobalHotkey|string|Command-49"
  "com.raycast.macos|raycastPreferredWindowMode|string|default"
  "com.raycast.macos|raycastShouldFollowSystemAppearance|bool|true"
  "com.raycast.macos|NSStatusItem Visible raycastIcon|bool|false"
  "com.raycast.macos|mainWindow_isMonitoringGlobalHotkeys|bool|true"
  "com.raycast.macos|fileSearch_fileSearchScope|string|kMDQueryScopeHome"
  "com.raycast.macos|useHyperKeyIcon|bool|false"
  "com.raycast.macos|faviconProvider|string|legacy"
  "com.raycast.macos|floatingNotes_raycastNotesFormatBarVisible|bool|false"
)

normalize_desired_value() {
  local type="$1"
  local value="$2"

  case "$type:$value" in
    bool:true)
      echo "1"
      ;;
    bool:false)
      echo "0"
      ;;
    *)
      echo "$value"
      ;;
  esac
}

normalize_current_value() {
  local type="$1"
  local value="$2"

  case "$type:$value" in
    bool:YES|bool:true)
      echo "1"
      ;;
    bool:NO|bool:false)
      echo "0"
      ;;
    *)
      echo "$value"
      ;;
  esac
}

redact_sensitive_diff() {
  sed -E \
    -e 's/((API|ACCESS|AUTH|PRIVATE|SECRET|SESSION|TOKEN|PASSWORD)[_A-Z0-9]*=)[^[:space:]]+/\1<redacted>/g' \
    -e 's/(sk-[A-Za-z0-9._-]+)/<redacted-secret>/g'
}

setting_status() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local desired="$4"
  local current
  local normalized_current
  local normalized_desired

  current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
  normalized_current="$(normalize_current_value "$type" "$current")"
  normalized_desired="$(normalize_desired_value "$type" "$desired")"

  if [[ -z "$current" ]]; then
    echo "missing"
  elif [[ "$normalized_current" == "$normalized_desired" || "$current" == "$desired" ]]; then
    echo "unchanged"
  else
    echo "different"
  fi
}

preview_file_sync() {
  local src="$1"
  local dest="$2"
  local status

  if [[ ! -e "$dest" ]]; then
    status="missing"
  elif cmp -s "$src" "$dest"; then
    status="unchanged"
  else
    status="different"
  fi

  echo "Source:      $src"
  echo "Destination: $dest"
  echo "Status:      $status"

  case "$status" in
    missing)
      echo "Destination missing; will create from source."
      ;;
    different)
      diff -u "$dest" "$src" | redact_sensitive_diff || true
      ;;
  esac

  echo
}

preview_directories() {
  local dir
  local status

  echo "== Directories =="
  for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
      status="exists"
    else
      status="missing"
    fi
    echo "$status: $dir"
  done
  echo
}

preview_defaults_group() {
  local title="$1"
  shift
  local settings=("$@")
  local setting
  local domain
  local key
  local type
  local desired
  local current
  local status

  echo "== $title =="
  for setting in "${settings[@]}"; do
    IFS='|' read -r domain key type desired <<< "$setting"
    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
    status="$(setting_status "$domain" "$key" "$type" "$desired")"

    echo "$domain $key"
    echo "  Type:    $type"
    echo "  Desired: $desired"
    if [[ -n "$current" ]]; then
      echo "  Current: $current"
    else
      echo "  Current: <missing>"
    fi
    echo "  Status:  $status"
  done
  echo
}

preview_sync() {
  local i

  echo "== Files =="
  for ((i = 0; i < ${#file_sources[@]}; i++)); do
    preview_file_sync "${file_sources[$i]}" "${file_destinations[$i]}"
  done

  preview_directories
  preview_defaults_group "macOS Defaults" "${mac_defaults[@]}"
  preview_defaults_group "Raycast Defaults" "${raycast_defaults[@]}"
}

write_default() {
  local domain="$1"
  local key="$2"
  local type="$3"
  local value="$4"

  defaults write "$domain" "$key" "-$type" "$value"
}

apply_defaults_group() {
  local settings=("$@")
  local setting
  local domain
  local key
  local type
  local desired

  for setting in "${settings[@]}"; do
    IFS='|' read -r domain key type desired <<< "$setting"
    write_default "$domain" "$key" "$type" "$desired"
  done
}

apply_sync() {
  local i
  local dir

  for dir in "${directories[@]}"; do
    mkdir -p "$dir"
  done

  for ((i = 0; i < ${#file_sources[@]}; i++)); do
    mkdir -p "$(dirname "${file_destinations[$i]}")"
    cp "${file_sources[$i]}" "${file_destinations[$i]}"
  done

  apply_defaults_group "${mac_defaults[@]}"
  apply_defaults_group "${raycast_defaults[@]}"

  killall Finder 2>/dev/null || true
  killall Dock 2>/dev/null || true

  echo "Sync complete. Restart Raycast if its preference changes are not visible."
}

preview_sync

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete. No changes applied."
  exit 0
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
  if ! read -r -p "Apply these sync changes? [y/N] " answer; then
    echo "Sync cancelled. No changes applied."
    exit 0
  fi
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Sync cancelled. No changes applied."
      exit 0
      ;;
  esac
fi

apply_sync
