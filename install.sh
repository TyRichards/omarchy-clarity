#!/bin/bash
set -euo pipefail

PLUGIN_ID=io.github.tyrichards.clarity
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

fail() {
  echo "clarity install: $*" >&2
  exit 1
}

[[ -t 0 && -t 1 ]] || fail "run this installer in an interactive terminal"
for command in python3 sudo systemctl resolvectl; do
  command -v "$command" >/dev/null || fail "required command not found: $command"
done

cat <<'INTRO'

Clarity setup
─────────────
Clarity will:
  • add root-owned sections to /etc/hosts;
  • permanently block the StevenBlack porn-only domain list;
  • start with the distraction block enabled;
  • install minute-by-minute schedule reconciliation and weekly list updates.

Choose a NEW Clarity password—not your Linux login password.
It is required to turn Clarity off or alter its schedule/site list.
INTRO

while true; do
  if command -v gum >/dev/null 2>&1; then
    password=$(gum input --password --prompt "New Clarity password: ") || exit 130
    confirmation=$(gum input --password --prompt "Confirm Clarity password: ") || exit 130
  else
    read -r -s -p "New Clarity password: " password
    printf '\n'
    read -r -s -p "Confirm Clarity password: " confirmation
    printf '\n'
  fi
  [[ ${#password} -ge 10 ]] || { echo "Use at least 10 characters." >&2; continue; }
  [[ $password == "$confirmation" ]] || { echo "Passwords did not match." >&2; continue; }
  break
done
unset confirmation

printf 'Authorizing one-time system installation…\n'
sudo -v
printf '%s\n' "$password" | sudo -n "$SCRIPT_DIR/lib/clarity-root" bootstrap "$SCRIPT_DIR" "$USER"
unset password

omarchy plugin enable "$PLUGIN_ID" right >/dev/null 2>&1 || true
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

cat <<'DONE'

Clarity is installed and ON.
The permanent adult-site block remains active even when the main toggle is off.
DONE
