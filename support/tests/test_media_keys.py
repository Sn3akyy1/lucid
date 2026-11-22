#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
import unittest


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


class MediaKeys(unittest.TestCase):
    def test_shipped_keys_follow_lucids_player(self):
        with open(os.path.join(ROOT, "support", "hypr", "keybinds.json"), encoding="utf-8") as f:
            binds = {entry["id"]: entry for entry in json.load(f)["binds"]}

        self.assertEqual(binds["xf86-play"]["cmd"], "qs ipc call media playPause")
        self.assertEqual(binds["xf86-pause"]["cmd"], "qs ipc call media playPause")
        self.assertEqual(binds["xf86-next"]["cmd"], "qs ipc call media next")
        self.assertEqual(binds["xf86-prev"]["cmd"], "qs ipc call media previous")

    def test_installer_only_migrates_old_defaults(self):
        with open(os.path.join(ROOT, "install.sh"), encoding="utf-8") as f:
            installer = f.read()
        with open(os.path.join(ROOT, "support", "hypr", "keybinds.json"), encoding="utf-8") as f:
            data = json.load(f)

        for command in ("playerctl play-pause", "playerctl next", "playerctl previous"):
            self.assertIn(command, installer)
        self.assertIn("media keys follow Lucid's active player now", installer)

        old = {
            "xf86-next": "playerctl next",
            "xf86-pause": "playerctl play-pause",
            "xf86-play": "my custom media command",
            "xf86-prev": "playerctl previous",
        }
        for bind in data["binds"]:
            if bind.get("id") in old:
                bind["cmd"] = old[bind["id"]]
        # Extract and run the installer itself, using multiline JSON to cover a
        # hand-formatted file as well as Settings' one-entry-per-line format.
        migration = installer.split("# Media keys used", 1)[1].split("<<'PY'\n", 1)[1].split("\nPY", 1)[0]
        with tempfile.NamedTemporaryFile("w+", suffix=".json") as target:
            json.dump(data, target, indent=2)
            target.flush()
            run = subprocess.run([
                "python3", "-", target.name, os.path.join(ROOT, "support", "hypr", "keybinds.json")
            ], input=migration, text=True, capture_output=True, check=False)
            self.assertEqual(run.returncode, 0, run.stderr)
            target.seek(0)
            migrated = {entry["id"]: entry["cmd"] for entry in json.load(target)["binds"] if entry.get("id") in old}

        self.assertEqual(migrated["xf86-next"], "qs ipc call media next")
        self.assertEqual(migrated["xf86-pause"], "qs ipc call media playPause")
        self.assertEqual(migrated["xf86-prev"], "qs ipc call media previous")
        self.assertEqual(migrated["xf86-play"], "my custom media command")


if __name__ == "__main__":
    unittest.main()
