#!/bin/bash
set -euo pipefail

PLUGIN_ID=io.github.tyrichards.clarity
ROOT_HELPER=/usr/local/lib/clarity/clarity-root

if [[ -x $ROOT_HELPER ]]; then
  [[ -t 0 && -t 1 ]] || { echo "clarity uninstall: administrator authorization requires an interactive terminal" >&2; exit 1; }
  printf 'Linux administrator authorization is required to restore system files.\n'
  sudo -k
  sudo -v
  sudo "$ROOT_HELPER" uninstall
fi

# Uninstallation never requires the Clarity password; Linux administrator
# authorization protects privileged system restoration.
omarchy plugin remove "$PLUGIN_ID" --yes
