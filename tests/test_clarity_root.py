#!/usr/bin/env python3

import importlib.util
from importlib.machinery import SourceFileLoader
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


PLUGIN_DIR = Path(__file__).resolve().parents[1]
HELPER = PLUGIN_DIR / "lib" / "clarity-root"
PASSWORD = "different-focus-password"


class ClarityRootTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "etc").mkdir(parents=True)
        self.original_hosts = "127.0.0.1 localhost\n192.0.2.10 keep.example.test\n"
        (self.root / "etc/hosts").write_text(self.original_hosts, encoding="utf-8")
        original_unit = self.root / "etc/systemd/system/clarity-reconcile.service"
        original_unit.parent.mkdir(parents=True)
        original_unit.write_text("original reconcile unit\n", encoding="utf-8")
        original_helper = self.root / "usr/local/lib/clarity/clarity-root"
        original_helper.parent.mkdir(parents=True)
        original_helper.write_text("original helper\n", encoding="utf-8")
        self.adult_source = self.root / "adult-hosts"
        self.adult_source.write_text(
            "127.0.0.1 localhost\n0.0.0.0 adult-one.test\n0.0.0.0 adult-two.test\n"
            "0.0.0.0 adult-three.test\n0.0.0.0 openai.com\n",
            encoding="utf-8",
        )
        focus = self.root / "focus-hosts"
        focus.write_text(
            "social-one.test\nsocial-two.test\nsocial-three.test\nsocial-four.test\n"
            "social-five.test\nchatgpt.com\nclaude.ai\nspotify.com\nmusic.youtube.com\nyoutube.com\n",
            encoding="utf-8",
        )
        self.env = os.environ.copy()
        self.env.update(
            {
                "CLARITY_TEST_ROOT": str(self.root),
                "CLARITY_ADULT_URLS": self.adult_source.as_uri(),
                "CLARITY_DISTRACTION_URLS": focus.as_uri(),
                "CLARITY_MIN_ADULT_DOMAINS": "3",
                "CLARITY_MIN_DISTRACTION_DOMAINS": "3",
            }
        )
        result = self.run_helper("bootstrap", str(PLUGIN_DIR), "testuser", "enabled", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)

    def tearDown(self):
        self.temp.cleanup()

    def run_helper(self, *args, input=None):
        return subprocess.run(
            [str(HELPER), *args],
            input=input,
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

    def status(self):
        result = self.run_helper("status")
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_bootstrap_blocks_both_categories(self):
        state = self.status()
        self.assertTrue(state["active"])
        self.assertTrue(state["backupsReady"])
        self.assertFalse(state["scheduleEnabled"])
        self.assertEqual(state["scheduleWindows"], [])
        self.assertEqual(state["permanentCount"], 3)
        self.assertEqual(state["categoryCounts"]["Adult"], 3)
        self.assertEqual(state["categoryCounts"]["Social & Feeds"], 6)
        self.assertEqual(len(state["categoryCounts"]), 6)
        self.assertEqual(state["whitelistSites"], [])
        self.assertTrue((self.root / "var/lib/clarity/backup-manifest.json").is_file())
        self.assertEqual(
            (self.root / "var/lib/clarity/hosts.pre-clarity").read_text(encoding="utf-8"),
            self.original_hosts,
        )
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertIn("0.0.0.0 adult-one.test", hosts)
        self.assertIn("# BEGIN CLARITY DISTRACTIONS", hosts)
        self.assertIn("192.0.2.10 keep.example.test", hosts)

    def test_sudoers_excludes_privileged_lifecycle_commands(self):
        sudoers = (self.root / "etc/sudoers.d/clarity").read_text(encoding="utf-8")
        self.assertNotIn("*", sudoers)
        for forbidden in ("bootstrap", "upgrade", "uninstall"):
            self.assertNotIn(forbidden, sudoers)
        for allowed in (
            "clarity-root status",
            "clarity-root enable",
            "clarity-root disable",
            "schedule-window-add",
            "whitelist-add",
            "clarity-root update-lists",
        ):
            self.assertIn(allowed, sudoers)
        self.assertTrue(
            all("NOPASSWD:" in line for line in sudoers.splitlines() if line.startswith("testuser "))
        )

    def test_lifecycle_scripts_force_linux_admin_authorization(self):
        installer = (PLUGIN_DIR / "install.sh").read_text(encoding="utf-8")
        uninstaller = (PLUGIN_DIR / "uninstall.sh").read_text(encoding="utf-8")
        cli = (PLUGIN_DIR / "bin/clarityctl").read_text(encoding="utf-8")
        for script in (installer, uninstaller, cli):
            self.assertIn("sudo -k", script)
            self.assertIn("sudo -v", script)
        self.assertNotIn('sudo -n "$ROOT_HELPER" upgrade', installer)
        self.assertNotIn('run_root uninstall', cli)
        self.assertNotIn('sudo -n "$ROOT_HELPER" uninstall', uninstaller)

    def test_shein_and_similar_shopping_sites_are_blocked(self):
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        for domain in (
            "shein.com",
            "us.shein.com",
            "romwe.com",
            "boohoo.com",
            "fashionnova.com",
            "shopcider.com",
            "dhgate.com",
            "shopee.com",
            "thredup.com",
        ):
            self.assertIn(domain, hosts)

    def test_ai_sites_are_removed_from_every_downloaded_feed(self):
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("openai.com", hosts)
        self.assertNotIn("chatgpt.com", hosts)
        self.assertNotIn("claude.ai", hosts)
        self.assertNotIn("spotify.com", hosts)
        self.assertNotIn("music.youtube.com", hosts)
        self.assertIn("youtube.com", hosts)
        self.assertIn("social-one.test", hosts)

    def test_setup_can_opt_out_of_permanent_adult_blocking(self):
        result = self.run_helper("uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.env["CLARITY_ADULT_URLS"] = (self.root / "does-not-exist").as_uri()
        result = self.run_helper(
            "bootstrap", str(PLUGIN_DIR), "testuser", "disabled", input=PASSWORD + "\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertFalse(state["permanentEnabled"])
        self.assertEqual(state["permanentCount"], 0)
        self.assertEqual(state["categoryCounts"]["Adult"], 0)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertIn("# BEGIN CLARITY DISTRACTIONS", hosts)

    def test_skipped_adult_blocking_can_be_enabled_later(self):
        result = self.run_helper("uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper(
            "bootstrap", str(PLUGIN_DIR), "testuser", "disabled", input=PASSWORD + "\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper("enable-adult")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertTrue(state["permanentEnabled"])
        self.assertEqual(state["permanentCount"], 3)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertIn("adult-one.test", hosts)

    def test_download_rejects_oversized_responses(self):
        oversized = self.root / "oversized-feed"
        oversized.write_text("a" * 65, encoding="utf-8")
        self.env["CLARITY_ADULT_URLS"] = oversized.as_uri()
        self.env["CLARITY_MAX_SOURCE_BYTES"] = "64"
        result = self.run_helper("update-lists")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("64-byte safety limit", result.stderr)

    def test_download_rejects_too_many_domains(self):
        crowded = self.root / "crowded-feed"
        crowded.write_text(
            "one.test\ntwo.test\nthree.test\nfour.test\n", encoding="utf-8"
        )
        self.env["CLARITY_ADULT_URLS"] = crowded.as_uri()
        self.env["CLARITY_MAX_SOURCE_DOMAINS"] = "3"
        result = self.run_helper("update-lists")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("3-domain safety limit", result.stderr)

    def test_failed_later_adult_enable_rolls_back_opt_out(self):
        result = self.run_helper("uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper(
            "bootstrap", str(PLUGIN_DIR), "testuser", "disabled", input=PASSWORD + "\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.env["CLARITY_ADULT_URLS"] = (self.root / "does-not-exist").as_uri()
        result = self.run_helper("enable-adult")
        self.assertNotEqual(result.returncode, 0)
        state = self.status()
        self.assertFalse(state["permanentEnabled"])
        self.assertEqual(state["permanentCount"], 0)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("# BEGIN CLARITY PERMANENT", hosts)

    def test_wrong_password_cannot_disable(self):
        result = self.run_helper("disable", input="wrong-password\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("incorrect Clarity password", result.stderr)
        self.assertTrue(self.status()["active"])

    def test_disable_keeps_permanent_block(self):
        result = self.run_helper("disable", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), " Success. Clarity Blocker is off.")
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertNotIn("# BEGIN CLARITY DISTRACTIONS", hosts)
        self.assertFalse(self.status()["active"])

    def test_schedule_mutation_requires_password(self):
        result = self.run_helper("schedule-state", "enabled", input=PASSWORD + "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("add at least one", result.stderr)
        result = self.run_helper("schedule-window-add", "22:00", "06:00", input="bad-password\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.status()["scheduleWindows"], [])
        result = self.run_helper("schedule-window-add", "22:00", "06:00", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertTrue(state["scheduleEnabled"])
        self.assertEqual(state["scheduleWindows"], [{"start": "22:00", "end": "06:00"}])
        result = self.run_helper("schedule-window-edit", "0", "21:00", "05:00", input="bad-password\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.status()["scheduleWindows"], [{"start": "22:00", "end": "06:00"}])
        result = self.run_helper("schedule-window-edit", "0", "21:00", "05:00", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.status()["scheduleWindows"], [{"start": "21:00", "end": "05:00"}])
        result = self.run_helper("schedule-window-remove", "0", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertFalse(state["scheduleEnabled"])
        self.assertEqual(state["scheduleWindows"], [])

    def test_schedule_rejects_overlaps_and_more_than_three_windows(self):
        result = self.run_helper("schedule-window-add", "22:00", "06:00", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        for start, end in (("23:00", "01:00"), ("05:00", "08:00")):
            result = self.run_helper("schedule-window-add", start, end, input=PASSWORD + "\n")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("may not overlap", result.stderr)
        result = self.run_helper("schedule-window-add", "18:00", "20:00", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper("schedule-window-add", "20:00", "21:00", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper("schedule-window-edit", "1", "23:30", "00:30", input=PASSWORD + "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("may not overlap", result.stderr)
        result = self.run_helper("schedule-window-add", "21:00", "22:00", input=PASSWORD + "\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("up to three", result.stderr)
        self.assertEqual(len(self.status()["scheduleWindows"]), 3)

    def test_whitelist_can_be_empty(self):
        result = self.run_helper("whitelist-set", input=PASSWORD + "\n# nothing yet\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.status()["whitelistCount"], 0)

    def test_whitelist_bypasses_focus_only(self):
        result = self.run_helper(
            "whitelist-set", input=PASSWORD + "\nadult-one.test\nsocial-one.test\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("adult-one.test", hosts)
        self.assertNotIn("social-one.test", hosts)
        self.assertEqual(self.status()["whitelistCount"], 2)

    def test_whitelist_mutation_requires_password(self):
        result = self.run_helper("whitelist-set", input="wrong-password\nsocial-one.test\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("incorrect Clarity password", result.stderr)
        self.assertEqual(self.status()["whitelistCount"], 0)

    def test_whitelist_add_accepts_a_url_and_deduplicates(self):
        rejected = self.run_helper(
            "whitelist-add", "https://social-one.test/something", input="wrong-password\n"
        )
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(self.status()["whitelistCount"], 0)
        for _ in range(2):
            result = self.run_helper(
                "whitelist-add", "https://social-one.test/something", input=PASSWORD + "\n"
            )
            self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertEqual(state["whitelistCount"], 1)
        self.assertEqual(state["whitelistSites"], ["social-one.test"])
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("social-one.test", hosts)

        rejected = self.run_helper("whitelist-remove", "social-one.test", input="wrong-password\n")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(self.status()["whitelistSites"], ["social-one.test"])
        result = self.run_helper("whitelist-remove", "social-one.test", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertEqual(state["whitelistCount"], 0)
        self.assertEqual(state["whitelistSites"], [])
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("social-one.test", hosts)

    def test_upgrade_removes_unused_legacy_default_schedule(self):
        config_file = self.root / "var/lib/clarity/config.json"
        config = json.loads(config_file.read_text(encoding="utf-8"))
        config.pop("scheduleConfigured", None)
        config["scheduleEnabled"] = True
        config["scheduleWindows"] = [{"start": "09:00", "end": "17:00"}]
        config_file.write_text(json.dumps(config), encoding="utf-8")
        result = self.run_helper("upgrade", str(PLUGIN_DIR))
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertFalse(state["scheduleEnabled"])
        self.assertEqual(state["scheduleWindows"], [])

    def test_upgrade_preserves_whitelist_and_setup_choice(self):
        result = self.run_helper("whitelist-set", input=PASSWORD + "\ncustom-focus.test\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper("upgrade", str(PLUGIN_DIR))
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertTrue(state["permanentEnabled"])
        whitelist = (self.root / "var/lib/clarity/whitelist.txt").read_text(encoding="utf-8")
        self.assertIn("custom-focus.test", whitelist)
        sites = (self.root / "var/lib/clarity/distractions.txt").read_text(encoding="utf-8")
        self.assertIn("youtube.com", sites)

    def test_uninstall_restores_exact_backups_and_requires_fresh_setup(self):
        hosts_file = self.root / "etc/hosts"
        hosts_file.write_text(
            hosts_file.read_text(encoding="utf-8") + "203.0.113.9 added-after-activation.test\n",
            encoding="utf-8",
        )
        result = self.run_helper("uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(hosts_file.read_text(encoding="utf-8"), self.original_hosts)
        self.assertEqual(
            (self.root / "etc/systemd/system/clarity-reconcile.service").read_text(encoding="utf-8"),
            "original reconcile unit\n",
        )
        self.assertEqual(
            (self.root / "usr/local/lib/clarity/clarity-root").read_text(encoding="utf-8"),
            "original helper\n",
        )
        self.assertFalse((self.root / "etc/systemd/system/clarity-adult-list.timer").exists())
        self.assertFalse((self.root / "etc/sudoers.d/clarity").exists())
        self.assertFalse((self.root / "var/lib/clarity").exists())
        self.assertNotEqual(self.run_helper("status").returncode, 0)

        new_password = "brand-new-clarity-password"
        result = self.run_helper(
            "bootstrap", str(PLUGIN_DIR), "testuser", "enabled", input=new_password + "\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotEqual(self.run_helper("disable", input=PASSWORD + "\n").returncode, 0)
        self.assertEqual(self.run_helper("disable", input=new_password + "\n").returncode, 0)

    def load_helper_module(self):
        old_root = os.environ.get("CLARITY_TEST_ROOT")
        os.environ["CLARITY_TEST_ROOT"] = str(self.root)
        try:
            loader = SourceFileLoader("clarity_root", str(HELPER))
            spec = importlib.util.spec_from_loader(loader.name, loader)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module
        finally:
            if old_root is None:
                os.environ.pop("CLARITY_TEST_ROOT", None)
            else:
                os.environ["CLARITY_TEST_ROOT"] = old_root

    def test_overnight_window_logic(self):
        module = self.load_helper_module()
        import datetime as dt

        config = {
            "scheduleWindows": [
                {"start": "09:00", "end": "12:00"},
                {"start": "22:00", "end": "06:00"},
            ]
        }
        self.assertTrue(module.inside_schedule(config, dt.datetime(2026, 1, 1, 10, 0)))
        self.assertTrue(module.inside_schedule(config, dt.datetime(2026, 1, 1, 23, 0)))
        self.assertTrue(module.inside_schedule(config, dt.datetime(2026, 1, 1, 5, 59)))
        self.assertFalse(module.inside_schedule(config, dt.datetime(2026, 1, 1, 12, 0)))

    def test_schedule_override_temporarily_beats_schedule(self):
        module = self.load_helper_module()
        import datetime as dt

        now = dt.datetime(2026, 1, 1, 12, 0).astimezone()
        future = (now + dt.timedelta(hours=1)).isoformat()
        past = (now - dt.timedelta(seconds=1)).isoformat()
        config = {
            "scheduleEnabled": True,
            "scheduleWindows": [{"start": "09:00", "end": "17:00"}],
            "scheduleOverrideActive": False,
            "scheduleOverrideUntil": future,
        }
        self.assertFalse(module.effective_active(config, now))
        config["scheduleOverrideActive"] = True
        config["scheduleWindows"] = [{"start": "18:00", "end": "19:00"}]
        self.assertTrue(module.effective_active(config, now))
        config["scheduleOverrideUntil"] = past
        self.assertFalse(module.effective_active(config, now))

    def test_primary_toggle_creates_24_hour_schedule_override(self):
        config_file = self.root / "var/lib/clarity/config.json"
        config = json.loads(config_file.read_text(encoding="utf-8"))
        config["scheduleEnabled"] = True
        config["scheduleWindows"] = [{"start": "23:58", "end": "23:59"}]
        config_file.write_text(json.dumps(config), encoding="utf-8")

        result = self.run_helper("enable")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertTrue(state["active"])
        self.assertTrue(state["scheduleEnabled"])
        self.assertTrue(state["scheduleOverrideActive"])
        self.assertNotEqual(state["scheduleOverrideUntil"], "")


if __name__ == "__main__":
    unittest.main()
