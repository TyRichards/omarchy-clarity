```text
                                ▄▄
                                    ██
██████  ██        ████  ██████  ██  ██████  ██  ██
██      ██      ██  ██  ██      ██  ██      ██  ██
██████  ██████  ██████  ██      ██  ████    ██████
                                                ██
by Ty Richards
```

# omarchy-clarity

An aggressive output guard for Omarchy’s top-right bar. **Clarity** can maintain a massive permanent adult-site blacklist and blocks social feeds, shopping, video, gambling, news, games, and other productivity killers while focus mode is active—without blocking major AI tools.

## Protection layers

### 1. Permanent adult blacklist — optional at first setup

The installer explicitly asks whether to enable permanent adult blocking.

- **Opt in:** Clarity downloads, validates, merges, de-duplicates, and locally stores three maintained feeds:
  - [Block List Project Porn](https://github.com/blocklistproject/Lists)
  - [HaGeZi NSFW](https://github.com/hagezi/dns-blocklists)
  - [StevenBlack `porn-only`](https://github.com/StevenBlack/hosts/tree/master/alternates/porn-only)
- **Opt out:** no adult feed is downloaded or applied.

This is a one-time setup choice. When enabled, the permanent blacklist is never affected by the main Clarity switch or schedule. It remains active until Clarity’s system integration is uninstalled. There is deliberately no later adult-block toggle.

The merged list is normally around one million unique domains, but the exact count changes as its maintainers add and remove entries. No finite blacklist can literally contain every present and future adult domain; this is a massive, regularly refreshed best-effort merge.

### 2. Output focus blacklist — controlled by Clarity

While Clarity is on, it merges ten remote category feeds with an aggressive bundled catalog:

- Social networks and feeds
- YouTube and other video platforms
- Facebook, TikTok, X/Twitter, and WhatsApp infrastructure
- Gambling and torrent sites
- Amazon retail, advertising/media infrastructure, Prime Video, Audible, IMDb, Goodreads, and international storefronts (AWS hosting is intentionally not blocked because it would break unrelated sites and AI tools)
- Shopping, auctions, deal hunting, and marketplaces
- Streaming video, livestreams, music discovery, and podcasts
- News cycles, opinion feeds, newsletters, forums, and viral content
- Sports, gaming, dating, food delivery, gossip, memes, and other rabbit holes

The remote feeds are refreshed weekly. The main switch only controls this focus list.

### AI stays available

`config/ai-allowlist.txt` is applied after every downloaded and bundled list. A listed domain and all of its subdomains are removed from both blocking layers.

The allowlist covers ChatGPT/OpenAI, Claude/Anthropic, Perplexity, Gemini, NotebookLM, Copilot, Mistral, Grok, Meta AI, Poe, Character.AI, DeepSeek, Hugging Face, Cursor, Windsurf, Replit, v0, Bolt, Lovable, Midjourney, Runway, Suno, ElevenLabs, and other major AI tools.

## Features

- Wi-Fi-style top-bar header and primary Clarity switch.
- Dedicated scrypt-hashed Clarity password—not the Linux login password.
- Password required to turn focus mode off.
- One optional daily focus window, including overnight windows.
- Password required to enable/disable the schedule, change times, or edit curated additions.
- Minute-by-minute systemd schedule reconciliation.
- Weekly refresh of all selected remote feeds.
- Atomic, marked `/etc/hosts` updates that preserve unrelated entries.
- Eight domains grouped per hosts row to reduce the size of million-domain sections.

## Important limitations

Clarity is strong local friction, not parental-control or enterprise security software. A person with sudo/root access can bypass software on their own machine. `/etc/hosts` cannot stop direct IP access, VPN/Tor/proxy traffic, remote browsers, or every newly created domain. Large category lists may cause false positives and can increase hostname-resolution work.

Version 0.2 intentionally **does not password-lock installation or uninstallation**. The Clarity password protects focus-mode disabling and schedule/site-list changes.

## Requirements

- Omarchy Quattro
- Python 3.11+
- systemd and systemd-resolved
- `sudo`, `visudo`, and internet access during setup

## Install

Omarchy’s manifest has no lifecycle hooks, so adding the plugin and enabling its system integration are separate steps:

```sh
omarchy plugin add https://github.com/TyRichards/omarchy-clarity.git --enable
~/.config/omarchy/plugins/io.github.tyrichards.clarity/install.sh
```

Alternatively, open the newly added panel and press **ACTIVATE**. Setup opens in a native Omarchy-themed 1:1 presentation pane with a single Clarity wordmark—no extra Omarchy splash screen.

The installer will:

1. Ask whether to enable or skip permanent adult blocking.
2. Ask for a new Clarity password.
3. Download and merge the selected blocklists.
4. Start Clarity on and install its timers.

To upgrade an existing installation after updating the plugin, rerun `install.sh`. It preserves the password, schedule, adult-block choice, and custom site additions while installing the new helper and refreshing feeds.

## Schedule

When enabled, Clarity is on from the start time up to—but not including—the end time:

- `09:00 → 17:00`: daytime focus.
- `22:00 → 06:00`: overnight focus.
- Equal start/end times: all-day focus.

The password is required to toggle the schedule or save new times.

## CLI

```sh
CLARITY=~/.config/omarchy/plugins/io.github.tyrichards.clarity/bin/clarityctl

$CLARITY status
$CLARITY on
$CLARITY off
$CLARITY schedule enabled 09:00 17:00
$CLARITY schedule disabled 09:00 17:00
$CLARITY sites list
$CLARITY sites edit
$CLARITY update-lists
```

Passwords are read from a hidden prompt or stdin and are never placed in process arguments. The root-owned record uses scrypt with a random salt; plaintext is not stored.

`sites edit` changes the local curated additions. Remote category feeds remain part of focus mode and cannot be emptied through the editor.

## Files and services

```text
/etc/hosts                                         Managed Clarity sections
/etc/sudoers.d/clarity                             Narrow helper permission
/etc/systemd/system/clarity-*.{service,timer}      Schedule/list timers
/usr/local/lib/clarity/clarity-root                 Root-owned helper
/var/lib/clarity/config.json                        Mode, setup choice, schedule
/var/lib/clarity/password.json                      Root-only scrypt record
/var/lib/clarity/adult-domains.txt                  Merged permanent feed
/var/lib/clarity/distraction-feed-domains.txt       Merged focus feeds
/var/lib/clarity/distractions.txt                   Curated/custom additions
/var/lib/clarity/ai-allowlist.txt                   Explicit AI exclusions
```

## Uninstall

Version 0.2 removal is deliberately not password-locked:

```sh
~/.config/omarchy/plugins/io.github.tyrichards.clarity/uninstall.sh
```

This disables timers, removes all Clarity sections from `/etc/hosts`, deletes root-owned state/helper files, and removes the Omarchy plugin. If permanent adult blocking was selected, uninstall is the operation that removes it.

Do not run `omarchy plugin remove` by itself because that removes only the UI. If that happens, clean up with:

```sh
sudo /usr/local/lib/clarity/clarity-root uninstall
```

## Validate

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.tyrichards.clarity
python3 -m unittest discover -v \
  ~/.config/omarchy/plugins/io.github.tyrichards.clarity/tests
```

## Licensing and feed attribution

Clarity’s code and bundled domain selections are MIT licensed. Remote blocklist data is downloaded during setup/refresh and is not committed into this repository:

- Block List Project: Unlicense/public domain
- HaGeZi DNS Blocklists: GPL-3.0
- StevenBlack hosts and its upstream sources: source-specific licenses documented by that project

Use of third-party feeds remains subject to their respective terms and disclaimers.
