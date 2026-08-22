#!/bin/bash
set -euo pipefail

PLUGIN_ID=io.github.tyrichards.clarity
ROOT_HELPER=/usr/local/lib/clarity/clarity-root

if [[ -x $ROOT_HELPER ]]; then
  sudo -v
  sudo -n "$ROOT_HELPER" uninstall
fi

# v1 intentionally does not password-lock uninstallation.
omarchy plugin remove "$PLUGIN_ID" --yes
