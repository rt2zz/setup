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

# Synced files, as "source|destination". Everything under home/ goes to the same
# path under $HOME, and destination folders are created as needed.
#
# Shared git and jj config go to files those tools read but don't write to by
# default, so ~/.gitconfig and ~/.config/jj/config.toml stay machine-local (gh
# credential helpers, git config --global, jj config set --user). git reads
# ~/.config/git/config before ~/.gitconfig, so local wins. jj reads conf.d/*.toml
# after config.toml, so shared wins; override it in conf.d/zz-local.toml.
files=()
for f in \
  "Library/Application Support/com.mitchellh.ghostty/config" \
  ".ssh/config.d/shared" \
  ".config/git/config" \
  ".config/jj/conf.d/shared.toml"; do
  files+=("$REPO_ROOT/home/$f|$HOME/$f")
done

# Ghostty only points TERMINFO at its bundle for shells it launches itself, so
# an ssh session into this Mac from Ghostty (TERM=xterm-ghostty) gets broken
# line editing unless the entry is in ~/.terminfo.
ghostty_terminfo="/Applications/Ghostty.app/Contents/Resources/terminfo/78/xterm-ghostty"
if [[ -f "$ghostty_terminfo" ]]; then
  files+=("$ghostty_terminfo|$HOME/.terminfo/78/xterm-ghostty")
fi

# Root-owned files. Applied with sudo only when they differ.
system_files=(
  "$REPO_ROOT/system/etc/pam.d/sudo_local|/etc/pam.d/sudo_local"
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

# sidecar runs this before publishing this repo when .sidecar sets
# review = "required". The reviewer is machine-local sidecar config, not part
# of .sidecar, so each Mac registers its own.
sidecar_reviewer="$(printf '%q' "$REPO_ROOT/mac/sidecar-review.sh")"

# defaults read prints bools as 1/0; the table above writes true/false.
normalize_value() {
  case "$1:$2" in
    bool:true|bool:YES)
      echo "1"
      ;;
    bool:false|bool:NO)
      echo "0"
      ;;
    *)
      echo "$2"
      ;;
  esac
}

# setting_status <type> <current> <desired>
setting_status() {
  if [[ -z "$2" ]]; then
    echo "missing"
  elif [[ "$(normalize_value "$1" "$2")" == "$(normalize_value "$1" "$3")" ]]; then
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
  local pair src dest

  header "System Files (sudo)"
  for pair in "${system_files[@]}"; do
    src="${pair%%|*}" dest="${pair#*|}"
    if system_file_supported "$dest"; then
      preview_file_sync "$src" "$dest"
    else
      echo "Destination: $dest"
      echo "Status:      $(colorize_status unsupported) (macOS 14+ only; will skip)"
      echo
    fi
  done
}

preview_defaults() {
  local setting domain key type desired current

  header "macOS Defaults"
  for setting in "${mac_defaults[@]}"; do
    IFS='|' read -r domain key type desired <<< "$setting"
    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"

    echo "$domain $key"
    echo "  Type:    $type"
    echo "  Desired: $desired"
    echo "  Current: ${current:-<missing>}"
    echo "  Status:  $(colorize_status "$(setting_status "$type" "$current" "$desired")")"
  done
  echo
}

# Prints the configured reviewer; fails when sidecar is missing or predates review.
current_sidecar_reviewer() {
  command -v sidecar >/dev/null 2>&1 && sidecar review reviewer 2>/dev/null
}

sidecar_reviewer_status() {
  local current

  if ! current="$(current_sidecar_reviewer)"; then
    echo "unsupported"
  elif [[ "$current" == "$sidecar_reviewer" ]]; then
    echo "unchanged"
  elif [[ "$current" == "no reviewer configured" ]]; then
    echo "missing"
  else
    echo "different"
  fi
}

preview_sidecar_reviewer() {
  local status

  header "Sidecar Reviewer"
  status="$(sidecar_reviewer_status)"
  echo "Desired: $sidecar_reviewer"
  case "$status" in
    unsupported)
      echo "Status:  $(colorize_status unsupported) (sidecar missing or without review; will skip)"
      ;;
    different)
      echo "Current: $(current_sidecar_reviewer)"
      echo "Status:  $(colorize_status different)"
      ;;
    *)
      echo "Status:  $(colorize_status "$status")"
      ;;
  esac
  echo
}

preview_sync() {
  local pair

  header "Files"
  for pair in "${files[@]}"; do
    preview_file_sync "${pair%%|*}" "${pair#*|}"
  done

  if [[ ! -e "$HOME/.gitconfig" ]]; then
    echo "$(colorize_status missing): $HOME/.gitconfig (will create empty, so git config --global and gh write there, not to the synced file)"
    echo
  fi

  preview_system_files

  header "Directories"
  if [[ -d "$HOME/Screenshots" ]]; then
    echo "$(colorize_status exists): $HOME/Screenshots"
  else
    echo "$(colorize_status missing): $HOME/Screenshots"
  fi
  echo

  preview_defaults
  preview_sidecar_reviewer
}

apply_sync() {
  local pair src dest setting domain key type desired current
  local defaults_changed=0

  for pair in "${files[@]}"; do
    src="${pair%%|*}" dest="${pair#*|}"
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
  done

  # git config --global writes to ~/.config/git/config when ~/.gitconfig is
  # absent; keep ~/.gitconfig present so local writes never land in the synced file.
  [[ -e "$HOME/.gitconfig" ]] || : > "$HOME/.gitconfig"

  for pair in "${system_files[@]}"; do
    src="${pair%%|*}" dest="${pair#*|}"
    if system_file_supported "$dest" && ! cmp -s "$src" "$dest"; then
      sudo install -m 444 -o root -g wheel "$src" "$dest"
    fi
  done

  # Screenshots land here (com.apple.screencapture location below).
  mkdir -p "$HOME/Screenshots"

  for setting in "${mac_defaults[@]}"; do
    IFS='|' read -r domain key type desired <<< "$setting"
    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
    if [[ "$(setting_status "$type" "$current" "$desired")" != unchanged ]]; then
      defaults write "$domain" "$key" "-$type" "$desired"
      defaults_changed=1
    fi
  done

  case "$(sidecar_reviewer_status)" in
    missing|different)
      sidecar review reviewer "$sidecar_reviewer"
      ;;
  esac

  # Restart what reads those defaults, only when one changed.
  if [[ "$defaults_changed" -eq 1 ]]; then
    killall Finder Dock SystemUIServer ControlCenter Spotlight 2>/dev/null || true
  fi

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
