#!/bin/bash
set -euo pipefail

PLUGIN_ID=io.github.tyrichards.clarity
ROOT_HELPER=/usr/local/lib/clarity/clarity-root
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

fail() {
  echo "clarity install: $*" >&2
  exit 1
}

show_clarity_logo() {
  local color=${GUM_CHOOSE_ITEM_FOREGROUND:-}
  local hex red green blue
  if [[ $color =~ ^#[[:xdigit:]]{6}$ ]]; then
    hex=${color#\#}
    red=$((16#${hex:0:2}))
    green=$((16#${hex:2:2}))
    blue=$((16#${hex:4:2}))
    printf '\033[38;2;%d;%d;%dm' "$red" "$green" "$blue"
  else
    printf '\033[39m'
  fi
  cat <<'LOGO'
 ▄████████  ▄█          ▄████████    ▄████████  ▄█      ███     ▄██   ▄
███    ███ ███         ███    ███   ███    ███ ███  ▀█████████▄ ███   ██▄
███    █▀  ███         ███    ███   ███    ███ ███▌    ▀███▀▀██ ███▄▄▄███
███        ███         ███    ███  ▄███▄▄▄▄██▀ ███▌     ███   ▀ ▀▀▀▀▀▀███
███        ███       ▀███████████ ▀▀███▀▀▀▀▀   ███▌     ███     ▄██   ███
███    █▄  ███         ███    ███ ▀███████████ ███      ███     ███   ███
███    ███ ███▌    ▄   ███    ███   ███    ███ ███      ███     ███   ███
████████▀  █████▄▄██   ███    █▀    ███    ███ █▀      ▄████▀    ▀█████▀
           ▀                        ███    ███
LOGO
  printf '\033[0m\n'
}

[[ -t 0 && -t 1 ]] || fail "run this installer in an interactive terminal"
for command in python3 sudo systemctl resolvectl; do
  command -v "$command" >/dev/null || fail "required command not found: $command"
done

if command -v omarchy-restart-gum >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source omarchy-restart-gum
fi

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

show_clarity_logo

cat <<'INTRO'
CLARITY SETUP
─────────────
Get focused. Be productive. Get Clarity.

Clarity does 2 things:

1. TURN DISTRACTIONS ON & OFF
   Toggle on/off or schedule access to distracting websites. (i.e. Social
   Media that scrolls infinitely). You must have a unique Clarity Password
   to manually toggle the switch off. You can specify which sites this
   includes after setup.

2. BLOCK ADULT SITES (Optional)
   The permanent adult blacklist is a one-time setup choice. If enabled, it
   is never affected by the Clarity toggle or schedule and remains until
   uninstall. If you opt out, you can also simply add adult sites to the
   regular "distractions" list to toggle on/off normally with others.

OTHER THINGS TO KNOW:
  • add root-owned sections to /etc/hosts;
  • permanently merge three massive, maintained adult-domain feeds;
  • aggressively block social, video, shopping, gambling, torrent, news,
    entertainment, and other output killers while focus mode is enabled;
  • explicitly allow major AI tools such as ChatGPT and Claude;
  • start with the distraction block enabled;
  • install minute-by-minute schedule reconciliation and weekly list updates.

─────────────

SET YOUR CLARITY PASSWORD

Choose a NEW Clarity password (not your Linux login password).
It is required to turn Clarity off or alter its schedule/site list.

The permanent adult blacklist is a one-time setup choice. If enabled, it is
never affected by the Clarity toggle or schedule and remains until uninstall.

INTRO

if command -v gum >/dev/null 2>&1; then
  adult_choice=$(printf '%s\n' \
    "Yes, enable permanent adult blacklist" \
    "Skip permanent blacklist (Add to distractions later)" |
    gum choose) || exit 130
else
  while true; do
    printf '%s\n' \
      "> Yes, enable permanent adult blacklist" \
      "  Skip permanent blacklist (Add to distractions later)"
    read -r -p "Choose permanent blacklist option [yes/skip]: " answer
    case ${answer,,} in
    y | yes) adult_choice="Yes, enable permanent adult blacklist"; break ;;
    n | no | s | skip) adult_choice="Skip permanent blacklist (Add to distractions later)"; break ;;
    esac
  done
fi
if [[ $adult_choice == Yes,* ]]; then
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
