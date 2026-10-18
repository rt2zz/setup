#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=mac/lib.sh
source "$SCRIPT_DIR/lib.sh"

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

# Shared git and jj config go to files those tools read but never write:
# git reads ~/.config/git/config before ~/.gitconfig, and jj reads conf.d/*.toml
# beside config.toml. ~/.gitconfig and ~/.config/jj/config.toml stay
# machine-local (gh credential helpers, identity overrides), and win on conflict.
file_sources=(
  "$REPO_ROOT/home/Library/Application Support/com.mitchellh.ghostty/config"
  "$REPO_ROOT/home/.ssh/config.d/shared"
  "$REPO_ROOT/home/.config/git/config"
  "$REPO_ROOT/home/.config/jj/conf.d/shared.toml"
)
file_destinations=(
  "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
  "$HOME/.ssh/config.d/shared"
  "$HOME/.config/git/config"
  "$HOME/.config/jj/conf.d/shared.toml"
)

# Ghostty only points TERMINFO at its bundle for shells it launches itself, so
# an ssh session into this Mac from Ghostty (TERM=xterm-ghostty) gets broken
# line editing unless the entry is in ~/.terminfo.
ghostty_terminfo="/Applications/Ghostty.app/Contents/Resources/terminfo/78/xterm-ghostty"
if [[ -f "$ghostty_terminfo" ]]; then
  file_sources+=("$ghostty_terminfo")
  file_destinations+=("$HOME/.terminfo/78/xterm-ghostty")
fi

# Root-owned files. Applied with sudo only when they differ.
system_file_sources=(
  "$REPO_ROOT/system/etc/pam.d/sudo_local"
)
system_file_destinations=(
  "/etc/pam.d/sudo_local"
)

directories=(
  "$HOME/Screenshots"
  "$HOME/Library/Application Support/com.mitchellh.ghostty"
  "$HOME/.ssh/config.d"
  "$HOME/.config/git"
  "$HOME/.config/jj/conf.d"
)

mac_defaults=(
  "com.apple.dock|autohide|bool|true"
  "com.apple.dock|autohide-delay|float|500"
  "com.apple.dock|autohide-time-modifier|float|0"
  "com.apple.dock|mcx-expose-disabled|bool|true"
  "NSGlobalDomain|KeyRepeat|int|1"
  "NSGlobalDomain|InitialKeyRepeat|int|10"
  "NSGlobalDomain|NSAutomaticSpellingCorrectionEnabled|bool|false"
  "NSGlobalDomain|WebAutomaticSpellingCorrectionEnabled|bool|false"
  "NSGlobalDomain|NSAutomaticCapitalizationEnabled|bool|false"
  "NSGlobalDomain|NSAutomaticPeriodSubstitutionEnabled|bool|false"
  "NSGlobalDomain|AppleEnableSwipeNavigateWithScrolls|bool|false"
  "NSGlobalDomain|NSAutomaticTextReplacementEnabled|bool|false"
  "NSGlobalDomain|WebAutomaticTextReplacementEnabled|bool|false"
  "NSGlobalDomain|NSWindowResizeTime|float|0.001"
  "com.apple.dock|expose-animation-duration|float|0.1"
  "com.apple.finder|DisableAllAnimations|bool|true"
  "com.apple.screencapture|location|string|$HOME/Screenshots"
  "com.apple.finder|QLEnableTextSelection|bool|true"
  "com.apple.finder|AppleShowAllFiles|bool|true"
  "NSGlobalDomain|com.apple.trackpad.scaling|float|0.875"
  "NSGlobalDomain|com.apple.swipescrolldirection|bool|false"
  "com.apple.Siri|StatusMenuVisible|bool|false"
  # Spotlight re-shows its icon on relaunch unless MenuItemHidden is set too.
  "com.apple.Spotlight|MenuItemHidden|int|1"
  "com.apple.Spotlight|NSStatusItem VisibleCC Item-0|bool|false"
  "com.apple.menuextra.clock|ShowDate|int|2"
  "com.apple.menuextra.clock|ShowDayOfWeek|bool|false"
  "com.apple.menuextra.clock|ShowAMPM|bool|false"
  "com.apple.menuextra.clock|Show24Hour|bool|true"
  "NSGlobalDomain|AppleICUForce24HourTime|bool|true"
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
  echo "Status:      $(colorize_status "$status")"

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

system_file_supported() {
  local dest="$1"

  case "$dest" in
    /etc/pam.d/sudo_local)
      # macOS 14+ includes sudo_local from /etc/pam.d/sudo.
      grep -q 'sudo_local' /etc/pam.d/sudo 2>/dev/null
      ;;
    *)
      return 0
      ;;
  esac
}

preview_system_files() {
  local i

  header "System Files (sudo)"
  for ((i = 0; i < ${#system_file_sources[@]}; i++)); do
    if system_file_supported "${system_file_destinations[$i]}"; then
      preview_file_sync "${system_file_sources[$i]}" "${system_file_destinations[$i]}"
    else
      echo "Destination: ${system_file_destinations[$i]}"
      echo "Status:      $(colorize_status unsupported) (macOS 14+ only; will skip)"
      echo
    fi
  done
}

preview_directories() {
  local dir
  local status

  header "Directories"
  for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
      status="exists"
    else
      status="missing"
    fi
    echo "$(colorize_status "$status"): $dir"
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

  header "$title"
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
    echo "  Status:  $(colorize_status "$status")"
  done
  echo
}

preview_sync() {
  local i

  header "Files"
  for ((i = 0; i < ${#file_sources[@]}; i++)); do
    preview_file_sync "${file_sources[$i]}" "${file_destinations[$i]}"
  done

  if [[ ! -e "$HOME/.gitconfig" ]]; then
    echo "$(colorize_status missing): $HOME/.gitconfig (will create empty, so git config --global and gh write there, not to the synced file)"
    echo
  fi

  preview_system_files
  preview_directories
  preview_defaults_group "macOS Defaults" "${mac_defaults[@]}"
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

  for ((i = 0; i < ${#system_file_sources[@]}; i++)); do
    if system_file_supported "${system_file_destinations[$i]}" &&
      ! cmp -s "${system_file_sources[$i]}" "${system_file_destinations[$i]}"; then
      sudo install -m 444 -o root -g wheel "${system_file_sources[$i]}" "${system_file_destinations[$i]}"
    fi
  done

  apply_defaults_group "${mac_defaults[@]}"

  killall Finder 2>/dev/null || true
  killall Dock 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
  killall ControlCenter 2>/dev/null || true
  killall Spotlight 2>/dev/null || true

  ok "Sync complete."
}

preview_sync

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete. No changes applied."
  exit 0
fi

if ! confirm "Apply these sync changes?" y; then
  skip "Sync cancelled. No changes applied."
  exit 0
fi

apply_sync
