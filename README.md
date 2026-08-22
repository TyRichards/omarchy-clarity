# omarchy-clarity

A focus guard for Omarchy’s top-right bar. **Clarity** blocks distracting sites during work or school hours and keeps a separate adult-site block active at all times.

## What it does

- Adds a Wi-Fi-style panel header with a primary **Clarity** switch.
- Blocks a curated list of social and high-scroll sites while Clarity is on.
- Requires a dedicated Clarity password—not the Linux login password—to turn Clarity off.
- Provides one optional daily focus window, including overnight windows.
- Requires the same Clarity password to enable/disable the schedule, change its times, or edit the distracting-site list.
- Installs the maintained [StevenBlack `porn-only` hosts list](https://github.com/StevenBlack/hosts/tree/master/alternates/porn-only) as an always-on permanent block.
- Refreshes the adult list weekly and reconciles the schedule every minute with systemd timers.

The adult block remains active whether the main Clarity switch and schedule are on or off. It is removed only by uninstalling Clarity’s system integration.

## Important limitations

Clarity is a strong local friction tool, not parental-control or enterprise security software. A person with sudo/root access can bypass any blocker installed on their own machine. `/etc/hosts` blocks exact hostnames, but cannot stop direct IP access, VPN/Tor/proxy traffic, remote browsers, or every future domain. Large category lists can also contain false positives.

Version 0.1 intentionally **does not password-lock installation or uninstallation**. The Clarity password protects disabling focus mode and changing its schedule/site list.

## Requirements

- Omarchy Quattro
- Python 3.11+
- systemd and systemd-resolved
- `sudo`, `visudo`, and internet access during setup

No additional package installation is required on a standard Omarchy system.

## Install

Omarchy’s plugin manifest format has no lifecycle hooks, so adding the plugin and installing its system integration are two explicit steps:

```sh
omarchy plugin add https://github.com/TyRichards/omarchy-clarity.git --enable
~/.config/omarchy/plugins/io.github.tyrichards.clarity/install.sh
```

The installer asks for a new Clarity password, downloads the permanent adult blocklist, updates `/etc/hosts`, starts the timers, and places the widget in the right bar section.

You can also open the newly added panel and press **Install Clarity**.

## Use

Click **󰌵 Clarity** in the top-right bar.

- Turning Clarity **on** is immediate.
- Turning Clarity **off** opens the dedicated password prompt.
- Enabling or disabling the daily schedule requires the password.
- **Save** updates the focus-window times after password confirmation.
- **Edit list** opens the configured terminal editor and requires the password before saving.

When the schedule is enabled, Clarity is on from the start time up to—but not including—the end time. For example:

- `09:00 → 17:00`: focus mode during the daytime.
- `22:00 → 06:00`: focus mode overnight.
- Equal start/end times mean an all-day focus window.

## CLI

The bundled CLI is useful for scripts and recovery:

```sh
CLARITY=~/.config/omarchy/plugins/io.github.tyrichards.clarity/bin/clarityctl

$CLARITY status
$CLARITY on
$CLARITY off
$CLARITY schedule enabled 09:00 17:00
$CLARITY schedule disabled 09:00 17:00
$CLARITY sites list
$CLARITY sites edit
$CLARITY update-adult
```

Passwords are read from a hidden prompt or stdin; they are never placed in process arguments. The root-owned password record uses Python’s scrypt implementation with a random salt. Plaintext is not stored.

## Files and services

```text
/etc/hosts                                      # Managed Clarity sections
/etc/sudoers.d/clarity                          # Narrow helper permission
/etc/systemd/system/clarity-*.{service,timer}   # Schedule/list timers
/usr/local/lib/clarity/clarity-root              # Root-owned helper
/var/lib/clarity/config.json                     # Schedule and mode state
/var/lib/clarity/password.json                   # Root-only scrypt record
/var/lib/clarity/adult-domains.txt               # Permanent category list
/var/lib/clarity/distractions.txt                # Password-guarded focus list
```

The helper preserves unrelated `/etc/hosts` entries. It writes only between clearly marked Clarity sections and uses atomic replacement.

## Uninstall

Version 0.1 removal is deliberately not password-locked:

```sh
~/.config/omarchy/plugins/io.github.tyrichards.clarity/uninstall.sh
```

This disables the timers, removes both Clarity sections from `/etc/hosts`, deletes Clarity’s root-owned state/helper, and removes the Omarchy plugin folder. Uninstalling removes the permanent adult block too.

Do not use `omarchy plugin remove` by itself: that only deletes the UI plugin and leaves the system blocker installed. If that happens, clean up with:

```sh
sudo /usr/local/lib/clarity/clarity-root uninstall
```

## Validate

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.tyrichards.clarity
qmllint -I "$OMARCHY_PATH/shell" \
  ~/.config/omarchy/plugins/io.github.tyrichards.clarity/Panel.qml
python3 -m unittest discover \
  ~/.config/omarchy/plugins/io.github.tyrichards.clarity/tests
```

## License and blocklist attribution

Plugin code is MIT licensed. The downloaded adult-domain data is assembled by [StevenBlack/hosts](https://github.com/StevenBlack/hosts), whose source list includes data under MIT, CC BY 4.0, and other source-specific terms documented in that project. Clarity does not redistribute a frozen copy; it downloads the current `porn-only` artifact during installation and weekly refreshes.
