# shellcheck shell=bash
# Shared helpers for mac/*.sh: colors, output, prompts, redaction.
# Sourced, not executed.

# Colors auto-disable when stdout is not a tty, NO_COLOR is set, or TERM=dumb.
# shellcheck disable=SC2034
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

header() { printf '\n%s\n' "${C_BOLD}${C_CYAN}== $1 ==${C_RESET}"; }
ok()     { printf '%s\n' "${C_GREEN}✓${C_RESET} $1"; }
skip()   { printf '%s\n' "${C_DIM}∙ $1${C_RESET}"; }
warn()   { printf '%s\n' "${C_YELLOW}!${C_RESET} $1"; }

colorize_status() {
  case "$1" in
    unchanged|exists)
      printf '%s' "${C_GREEN}$1${C_RESET}"
      ;;
    missing|different)
      printf '%s' "${C_YELLOW}$1${C_RESET}"
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

# confirm <prompt> <default: y|n> — when ASSUME_YES=1, the default is taken.
confirm() {
  local prompt="$1"
  local default="$2"
  local suffix answer

  if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
    [[ "$default" == "y" ]]
    return
  fi

  if [[ "$default" == "y" ]]; then
    suffix="${C_DIM}[Y/n]${C_RESET}"
  else
    suffix="${C_DIM}[y/N]${C_RESET}"
  fi

  printf '%s %s %s ' "${C_BOLD}${C_BLUE}?${C_RESET}" "${C_BOLD}${prompt}${C_RESET}" "$suffix"
  read -r answer || answer=""
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[yY] ]]
}

# ~/.zshrc and other synced files can contain exported API keys.
redact_sensitive_diff() {
  sed -E \
    -e 's/((API|ACCESS|AUTH|PRIVATE|SECRET|SESSION|TOKEN|PASSWORD)[_A-Z0-9]*=)[^[:space:]]+/\1<redacted>/g' \
    -e 's/(sk-[A-Za-z0-9._-]+)/<redacted-secret>/g'
}
