#!/usr/bin/env python3
# python3 -m unittest support/tests/i18n/test_regressions.py -v
# things the final review found, pinned so they stay fixed
import json
import os
import re
import unittest

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def catalogue():
    return json.loads(read("i18n/es.json"))


class Homonyms(unittest.TestCase):
    """one English word, two meanings: each gets its own context"""

    def test_weather_clear_is_not_the_clear_button(self):
        self.assertIn('I18n.trc("weather", "Clear")', read("WeatherSource.qml"))
        self.assertNotEqual(catalogue()["Clear"], catalogue()["weather|Clear"])

    def test_blur_light_is_not_the_light_theme(self):
        self.assertIn('I18n.trc("blur", "Light")', read("lucidprefs/GlassPage.qml"))

    def test_hotspot_start_is_a_verb(self):
        self.assertIn('I18n.trc("verb", "Start")', read("lucidprefs/NetworkPage.qml"))



class Unwrapped(unittest.TestCase):
    """texts the line-based checker cannot see"""

    def test_saved_network(self):
        self.assertNotIn('bits.push("Saved")', read("lucidprefs/WifiRow.qml"))

    def test_phone_widget_says(self):
        self.assertIsNone(re.search(r'w\.say\("', read("lucidwidgets/KdeconnectWidget.qml")))

    def test_launcher_open_url(self):
        self.assertNotIn('"Open " + url', read("luciddocks/Dock.qml"))

    def test_palette_import_failed(self):
        self.assertNotIn('"Import failed."', read("lucidprefs/PalettesPage.qml").replace('I18n.tr("Import failed.")', ""))

    def test_screenshot_notifications(self):
        src = read("shell.qml") + read("lucidshot/ShotCard.qml")
        for text in ("Recording saved", "Screenshot copied", "Screenshot saved", "Edited copy saved"):
            self.assertNotIn('"' + text + '"', src.replace('I18n.tr("' + text + '")', ""))


class Locale(unittest.TestCase):
    def test_no_system_locale_left(self):
        left = []
        for d, _dirs, names in os.walk(ROOT):
            rel = os.path.relpath(d, ROOT)
            if rel.startswith((".git", ".superpowers", "support", "docs")):
                continue
            for n in names:
                if n.endswith(".qml") and "Qt.locale()" in read(os.path.join(rel, n)):
                    left.append(os.path.join(rel, n))
        self.assertEqual(left, [])


class LanguagePicker(unittest.TestCase):
    def test_automatic_button_stays_short(self):
        # with Settings tiled to half the screen the segment has no room for the language name
        self.assertNotIn('I18n.tr("Automatic (%1)"', read("lucidprefs/GeneralPage.qml"))


class PresetNames(unittest.TestCase):
    def test_free_name_checks_what_it_suggests(self):
        src = read("lucidprefs/PresetSaveTile.qml")
        self.assertNotIn('"Layout " + n', src)


if __name__ == "__main__":
    unittest.main()
