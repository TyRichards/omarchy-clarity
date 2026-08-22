#!/bin/bash
set -euo pipefail

PLUGIN_ID=io.github.tyrichards.clarity
ROOT_HELPER=/usr/local/lib/clarity/clarity-root
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

fail() {
  echo "clarity install: $*" >&2
  exit 1
}

[[ -t 0 && -t 1 ]] || fail "run this installer in an interactive terminal"
for command in python3 sudo systemctl resolvectl; do
  command -v "$command" >/dev/null || fail "required command not found: $command"
done

if [[ -x $ROOT_HELPER ]]; then
  printf 'Upgrading Clarity blocklists and system integration…\n'
  sudo -v
  sudo install -Dm755 "$SCRIPT_DIR/lib/clarity-root" "$ROOT_HELPER"
  sudo -n "$ROOT_HELPER" upgrade "$SCRIPT_DIR"
  omarchy plugin enable "$PLUGIN_ID" right >/dev/null 2>&1 || true
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  printf '\nClarity is upgraded; your password, schedule, and custom sites were preserved.\n'
  exit 0
fi

cat <<'INTRO'

Clarity setup
─────────────
Clarity will:
  • add root-owned sections to /etc/hosts;
  • permanently merge three massive, maintained adult-domain feeds;
  • aggressively block social, video, shopping, gambling, torrent, news,
    entertainment, and other output killers while focus mode is enabled;
  • explicitly allow major AI tools such as ChatGPT and Claude;
  • start with the distraction block enabled;
  • install minute-by-minute schedule reconciliation and weekly list updates.

The permanent adult blacklist is a one-time setup choice. If enabled, it is
never affected by the Clarity toggle or schedule and remains until uninstall.

Choose a NEW Clarity password—not your Linux login password.
It is required to turn Clarity off or alter its schedule/site list.
INTRO

if command -v gum >/dev/null 2>&1; then
  adult_choice=$(printf '%s\n' \
    "Enable permanent adult blacklist (recommended)" \
    "Skip permanent adult blacklist" |
    gum choose --header "Permanent adult-site blocking cannot be toggled later:") || exit 130
else
  while true; do
    read -r -p "Enable permanent adult blacklist until uninstall? [y/n]: " answer
    case ${answer,,} in
    y | yes) adult_choice="Enable permanent adult blacklist (recommended)"; break ;;
    n | no) adult_choice="Skip permanent adult blacklist"; break ;;
    esac
  done
fi
if [[ $adult_choice == Enable* ]]; then
  adult_state=enabled
else
  adult_state=disabled
fi

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
printf '%s\n' "$password" | sudo -n "$SCRIPT_DIR/lib/clarity-root" bootstrap "$SCRIPT_DIR" "$USER" "$adult_state"
unset password

omarchy plugin enable "$PLUGIN_ID" right >/dev/null 2>&1 || true
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

cat <<'DONE'

Clarity is installed and ON.
DONE

if [[ $adult_state == enabled ]]; then
  echo "The permanent adult-site block is active until Clarity is uninstalled."
else
  echo "Permanent adult-site blocking was skipped during setup."
fi
