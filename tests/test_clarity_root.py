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
        (self.root / "etc/hosts").write_text(
            "127.0.0.1 localhost\n192.0.2.10 keep.example.test\n", encoding="utf-8"
        )
        adult = self.root / "adult-hosts"
        adult.write_text(
            "127.0.0.1 localhost\n0.0.0.0 adult-one.test\n0.0.0.0 adult-two.test\n"
            "0.0.0.0 adult-three.test\n0.0.0.0 openai.com\n",
            encoding="utf-8",
        )
        focus = self.root / "focus-hosts"
        focus.write_text(
            "social-one.test\nsocial-two.test\nsocial-three.test\nchatgpt.com\nclaude.ai\n",
            encoding="utf-8",
        )
        self.env = os.environ.copy()
        self.env.update(
            {
                "CLARITY_TEST_ROOT": str(self.root),
                "CLARITY_ADULT_URLS": adult.as_uri(),
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
        self.assertEqual(state["permanentCount"], 3)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertIn("0.0.0.0 adult-one.test", hosts)
        self.assertIn("# BEGIN CLARITY DISTRACTIONS", hosts)
        self.assertIn("192.0.2.10 keep.example.test", hosts)

    def test_ai_sites_are_removed_from_every_downloaded_feed(self):
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("openai.com", hosts)
        self.assertNotIn("chatgpt.com", hosts)
        self.assertNotIn("claude.ai", hosts)
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
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertIn("# BEGIN CLARITY DISTRACTIONS", hosts)

    def test_wrong_password_cannot_disable(self):
        result = self.run_helper("disable", input="wrong-password\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("incorrect Clarity password", result.stderr)
        self.assertTrue(self.status()["active"])

    def test_disable_keeps_permanent_block(self):
        result = self.run_helper("disable", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertIn("# BEGIN CLARITY PERMANENT", hosts)
        self.assertNotIn("# BEGIN CLARITY DISTRACTIONS", hosts)
        self.assertFalse(self.status()["active"])

    def test_schedule_mutation_requires_password(self):
        result = self.run_helper("schedule-set", "enabled", "22:00", "06:00", input="bad-password\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.status()["scheduleEnabled"])
        result = self.run_helper("schedule-set", "enabled", "22:00", "06:00", input=PASSWORD + "\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertTrue(state["scheduleEnabled"])
        self.assertEqual(state["scheduleStart"], "22:00")
        self.assertEqual(state["scheduleEnd"], "06:00")

    def test_empty_site_list_is_rejected(self):
        result = self.run_helper("sites-set", input=PASSWORD + "\n# nothing\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("may not be empty", result.stderr)

    def test_upgrade_preserves_custom_sites_and_setup_choice(self):
        result = self.run_helper("sites-set", input=PASSWORD + "\ncustom-focus.test\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_helper("upgrade", str(PLUGIN_DIR))
        self.assertEqual(result.returncode, 0, result.stderr)
        state = self.status()
        self.assertTrue(state["permanentEnabled"])
        sites = (self.root / "var/lib/clarity/distractions.txt").read_text(encoding="utf-8")
        self.assertIn("custom-focus.test", sites)
        self.assertIn("youtube.com", sites)

    def test_uninstall_removes_only_managed_sections(self):
        result = self.run_helper("uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        hosts = (self.root / "etc/hosts").read_text(encoding="utf-8")
        self.assertNotIn("CLARITY", hosts)
        self.assertIn("192.0.2.10 keep.example.test", hosts)
        self.assertFalse((self.root / "var/lib/clarity").exists())

    def test_overnight_window_logic(self):
        old_root = os.environ.get("CLARITY_TEST_ROOT")
        os.environ["CLARITY_TEST_ROOT"] = str(self.root)
        try:
            loader = SourceFileLoader("clarity_root", str(HELPER))
            spec = importlib.util.spec_from_loader(loader.name, loader)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            import datetime as dt

            config = {"scheduleStart": "22:00", "scheduleEnd": "06:00"}
            self.assertTrue(module.inside_schedule(config, dt.datetime(2026, 1, 1, 23, 0)))
            self.assertTrue(module.inside_schedule(config, dt.datetime(2026, 1, 1, 5, 59)))
            self.assertFalse(module.inside_schedule(config, dt.datetime(2026, 1, 1, 12, 0)))
        finally:
            if old_root is None:
                os.environ.pop("CLARITY_TEST_ROOT", None)
            else:
                os.environ["CLARITY_TEST_ROOT"] = old_root


if __name__ == "__main__":
    unittest.main()
