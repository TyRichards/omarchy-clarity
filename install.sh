#!/bin/bash
set -euo pipefail

PLUGIN_ID=io.github.tyrichards.clarity
ROOT_HELPER=/usr/local/lib/clarity/clarity-root
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

fail() {
  echo "clarity install: $*" >&2
  exit 1
}

authorize_admin() {
  [[ -t 0 && -t 1 ]] || fail "administrator authorization requires an interactive terminal"
  sudo -k
  sudo -v
}

set_ansi_color() {
  local color=$1
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
}

set_accent_color() {
  set_ansi_color "${GUM_CHOOSE_CURSOR_FOREGROUND:-${GUM_CHOOSE_ITEM_FOREGROUND:-}}"
}

reset_ansi_color() {
  printf '\033[0m'
}

show_clarity_logo() {
  set_ansi_color "${GUM_CHOOSE_ITEM_FOREGROUND:-}"
  cat "$SCRIPT_DIR/clarity-ascii.txt"
  reset_ansi_color
  printf '\n'
}

clear_onboarding() {
  printf '\033[2J\033[H'
}

section_header() {
  local title=$1
  local width=72
  local fill=$((width - ${#title} - 1))
  local rule
  printf -v rule '%*s' "$fill" ''
  set_accent_color
  printf '%s %s\n' "$title" "${rule// /░}"
  reset_ansi_color
}

show_selector() {
  local index=$1
  if ((onboarding_focus == index)); then
    set_accent_color
    printf '> '
    reset_ansi_color
  else
    printf '  '
  fi
}

show_focus_row() {
  local index=$1
  local label=$2
  local accented=${3:-false}
  show_selector "$index"
  if [[ $accented == true ]]; then
    set_accent_color
    printf '%s' "$label"
    reset_ansi_color
    printf '\n'
  else
    printf '%s\n' "$label"
  fi
}

show_detail_row() {
  local index=$1
  local heading=$2
  local expanded=$3
  local action='▓  VIEW DETAILS ▓'
  [[ $expanded == true ]] && action='▓  VIEW DETAILS ▓'

  show_selector "$index"
  printf '%s  ' "$heading"
  set_accent_color
  printf '%s' "$action"
  reset_ansi_color
  printf '\n'
}

show_distraction_details() {
  cat <<'DETAILS'
   Toggle on/off or schedule access to distracting websites. (i.e. Social
   Media that scrolls infinitely). You must have a unique Clarity Password
   to manually toggle the switch off. Sites you still need can be added to
   a simple focus whitelist after setup.
DETAILS
}

show_adult_details() {
  cat <<'DETAILS'
   Opting into the persistent adult blacklist is an initial setup choice. If
   enabled, it is never affected by the Clarity toggle or schedule and remains
   until uninstall of this plugin. If you skip it now, no adult feed is applied;
   you can permanently enable it later from the Clarity panel.
DETAILS
}

show_technical_details() {
  cat <<'DETAILS'
  • add root-owned sections to /etc/hosts;
  • aggressively block social, video, shopping, gambling, torrent, news,
    entertainment, and other output killers while clarity mode is enabled;
  • persistently merge three massive, well-maintained adult-domain feeds;
  • explicitly allow major AI tools such as ChatGPT and Claude;
  • start with the distraction block enabled;
  • install persistent schedule reconciliation and weekly list updates.
DETAILS
}

build_onboarding_frame() {
  show_clarity_logo
  printf '\nGet Focused. Get Productive. Get Clarity.\n\n\n\n'
  section_header 'CLARITY SETUP'
  printf '\n\nClarity does 2 things for you:\n\n'

  show_detail_row 0 '1. TURN DISTRACTING SITES ON & OFF (Or Schedule)' "$distraction_expanded"
  if [[ $distraction_expanded == true ]]; then
    printf '\n'
    show_distraction_details
    printf '\n'
  fi
  printf '\n'
  show_detail_row 1 '2. BLOCK ADULT SITES (Optional)' "$adult_expanded"
  if [[ $adult_expanded == true ]]; then
    printf '\n'
    show_adult_details
    printf '\n'
  fi
  printf '\n'
  show_detail_row 2 '  TECHNICAL THINGS UNDER THE HOOD' "$technical_expanded"
  if [[ $technical_expanded == true ]]; then
    printf '\n'
    show_technical_details
    printf '\n'
  fi

  printf '\n\n\n'
  show_focus_row 3 '▓  CREATE NEW CLARITY PASSWORD ▓' true
}

render_onboarding() {
  local frame
  frame=$(build_onboarding_frame)

  # Clear the complete viewport inside a synchronized update before drawing.
  # Overwriting from cursor-home leaves stale text when an expanded row closes.
  printf '\033[?2026h\033[2J\033[H%s\n\033[?2026l' "$frame"
}

read_onboarding_key() {
  local first rest=''
  IFS= read -r -s -n 1 first || exit 130
  if [[ $first == $'\e' ]]; then
    IFS= read -r -s -n 2 -t 0.1 rest || true
  fi
  onboarding_key=$first$rest
}

run_onboarding() {
  onboarding_focus=0
  distraction_expanded=false
  adult_expanded=false
  technical_expanded=false

  while true; do
    render_onboarding
    read_onboarding_key
    case $onboarding_key in
    $'\e[A' | k) onboarding_focus=$(((onboarding_focus + 3) % 4)) ;;
    $'\e[B' | j) onboarding_focus=$(((onboarding_focus + 1) % 4)) ;;
    $'\e' | q) exit 130 ;;
    '')
      case $onboarding_focus in
      0)
        if [[ $distraction_expanded == true ]]; then
          distraction_expanded=false
        else
          distraction_expanded=true
          adult_expanded=false
          technical_expanded=false
        fi
        ;;
      1)
        if [[ $adult_expanded == true ]]; then
          adult_expanded=false
        else
          distraction_expanded=false
          adult_expanded=true
          technical_expanded=false
        fi
        ;;
      2)
        if [[ $technical_expanded == true ]]; then
          technical_expanded=false
        else
          distraction_expanded=false
          adult_expanded=false
          technical_expanded=true
        fi
        ;;
      3) return ;;
      esac
      ;;
    esac
  done
}

show_password_intro() {
  clear_onboarding
  show_clarity_logo
  printf '\nGet Focused. Get Productive. Get Clarity.\n\n\n\n'
  section_header 'CREATE CLARITY PASSWORD'
  cat <<'INTRO'


Choose a NEW Clarity password. (Not your Linux login password)

Clarity password is required to turn Clarity toggle off or alter Clarity
schedule or whitelist. Many people have a trusted friend enter the password.



INTRO
}

show_adult_choice_intro() {
  clear_onboarding
  show_clarity_logo
  printf '\nGet Focused. Get Productive. Get Clarity.\n\n\n\n'
  section_header 'ADULT BLACKLIST OPTION'
  cat <<'INTRO'


Choose whether to enable the permanent adult blacklist:
(This initial choice is separate from the Clarity toggle and focus schedule)

INTRO
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
  printf 'Linux administrator authorization is required for this upgrade.\n'
  authorize_admin
  sudo install -Dm755 "$SCRIPT_DIR/lib/clarity-root" "$ROOT_HELPER"
  sudo "$ROOT_HELPER" upgrade "$SCRIPT_DIR"
  omarchy plugin enable "$PLUGIN_ID" right >/dev/null 2>&1 || true
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  printf '\nClarity is ready with your clarity password, schedule off, full list, and no whitelist yet.\n'
  exit 0
fi

run_onboarding
show_password_intro

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

show_adult_choice_intro
if command -v gum >/dev/null 2>&1; then
  adult_choice=$(printf '%s\n' \
    "YES - Enable persistent adult blacklist" \
    "NO - Skip persistent blacklist" |
    gum choose --header "") || exit 130
else
  printf '%s\n' \
    "> YES - Enable persistent adult blacklist" \
    "  NO - Skip persistent blacklist"
  while true; do
    read -r -p "Choose [yes/no]: " answer
    case ${answer,,} in
    y | yes) adult_choice="YES - Enable persistent adult blacklist"; break ;;
    n | no) adult_choice="NO - Skip persistent blacklist"; break ;;
    esac
  done
fi
if [[ $adult_choice == YES* ]]; then
  adult_state=enabled
else
  adult_state=disabled
fi

printf 'Linux administrator authorization is required for this one-time system installation…\n'
authorize_admin
printf '%s\n' "$password" | sudo "$SCRIPT_DIR/lib/clarity-root" bootstrap "$SCRIPT_DIR" "$USER" "$adult_state"
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
