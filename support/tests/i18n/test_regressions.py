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



def shell_qml():
    """(path, text) of every QML file of the shell itself"""
    for d, dirs, names in os.walk(ROOT):
        rel = os.path.relpath(d, ROOT)
        if rel.startswith((".git", "support", "docs", "i18n")):
            dirs[:] = []
            continue
        for n in names:
            if n.endswith(".qml"):
                path = os.path.normpath(os.path.join(rel, n))
                yield path, read(path)


# a Qt date or time format: runs of one code letter, outside 'quoted' text
FORMAT_TOKEN = re.compile(r"'[^']*'|AP|ap|d+|M+|y+|H+|h+|m+|s+|z+|t")


def format_tokens(fmt):
    return sorted(t for t in FORMAT_TOKEN.findall(fmt) if not t.startswith("'"))


class DateFormats(unittest.TestCase):
    """a format handed to toLocaleDateString and the like is codes Qt reads, not
    words: ru.json once had "ЧЧ:мм" for HH:mm and "PM" for AP, and the clocks
    printed them as they were"""

    def test_translations_keep_the_codes(self):
        call = re.compile(r"toLocale(Date|Time)?String|formatDate|formatTime|formatDateTime|\.toString\(")
        used = set()
        for _path, text in shell_qml():
            for line in text.split("\n"):
                if call.search(line):
                    used.update(re.findall(r'I18n\.tr\("((?:[^"\\]|\\.)*)"\)', line))
        formats = {k for k in used if re.fullmatch(r"[dMyHhmsztAPap :,./\-]+", k) and re.search(r"[dMyHhm]", k)}
        self.assertTrue(formats)
        for code in ("es", "ru"):
            cat = json.loads(read(f"i18n/{code}.json"))
            for k in sorted(formats):
                v = cat.get(k, "")
                if v:
                    self.assertEqual(format_tokens(v), format_tokens(k), f"{code}: {k!r} -> {v!r}")


class SavedDefaults(unittest.TestCase):
    """a JsonAdapter default that calls I18n is a binding: a language change
    re-runs it and the FileView saves it over what the file held (the dock lost
    every pin that way)"""

    def test_no_translated_defaults(self):
        left = []
        for path, text in shell_qml():
            for m in re.finditer(r"JsonAdapter\s*\{", text):
                i, depth = m.end(), 1
                while i < len(text) and depth:
                    depth += {"{": 1, "}": -1}.get(text[i], 0)
                    i += 1
                if "I18n." in text[m.start():i]:
                    left.append(path)
        self.assertEqual(left, [])


class SettingsSearch(unittest.TestCase):
    """SettingsIndex reads the rows out of the page files; it has to see a title
    through I18n.tr, or search finds no row at all"""

    def test_rows_are_found(self):
        lit = re.compile(r'^(?:I18n\.tr\(("(?:[^"\\]|\\.)*")\)|("(?:[^"\\]|\\.)*"))$')
        rows = 0
        for n in os.listdir(os.path.join(ROOT, "lucidprefs")):
            if not n.endswith("Page.qml"):
                continue
            lines = read(os.path.join("lucidprefs", n)).split("\n")
            for i, line in enumerate(lines):
                m = re.match(r"^( *)SettingRow \{$", line)
                if not m:
                    continue
                inner = m.group(1) + "    "
                for later in lines[i + 1:]:
                    if later == m.group(1) + "}":
                        break
                    t = re.match("^" + inner + r"title: (.*)$", later)
                    if t and lit.match(t.group(1)):
                        rows += 1
                        break
        # 397 rows on 2026-11-20; a parser that misses I18n.tr finds none
        self.assertGreater(rows, 300)
        self.assertIn('/^I18n\\.tr\\(', read("lucidprefs/SettingsIndex.qml"))


class WindowRules(unittest.TestCase):
    """hyprland floats some of the shell's windows by their title, so those
    titles stay in English"""

    def test_matched_titles_are_not_translated(self):
        rules = read("support/hypr/modules/windowrules.lua")
        titles = re.findall(r'class = "org\.quickshell", title = "([^"^$\\()|.*+?]+)"', rules)
        self.assertTrue(titles)
        code = "\n".join(text for _p, text in shell_qml())
        for t in titles:
            self.assertIn(f'title: "{t}"', code)
            self.assertNotIn(f'title: I18n.tr("{t}")', code)



class OwnApps(unittest.TestCase):
    """OwnApps.qml translates lucid's own launcher entries by their English text,
    so that text has to be what the scripts write into the .desktop files"""

    writers = {
        "lucid.clock": "lucidclock/clock",
        "lucid.lumen": "lucidlumen/lumen",
        "lucid.lens": "lucidlens/lens",
        "org.quickshell": "install.sh",
    }

    def table(self):
        src = read("OwnApps.qml")
        out = {}
        for m in re.finditer(r'"([\w.]+)": \{(.*?)\n        \}', src, re.S):
            out[m.group(1)] = re.findall(r'"((?:[^"\\]|\\.)*)": I18n\.tr\("\1"\)', m.group(2))
        return out

    def test_words_are_what_the_desktop_files_say(self):
        table = self.table()
        for app, script in self.writers.items():
            self.assertIn(app, table)
            text = read(script)
            for word in table[app]:
                self.assertRegex(text, r"(?m)^(Name|Comment)=" + re.escape(word) + "$", f"{app}: {word!r} is not in {script}")

    def test_every_entry_has_its_name(self):
        table = self.table()
        for app, script in self.writers.items():
            if app == "org.quickshell":
                name = re.search(r"(?m)^Name=(Lucid .*)$", read(script)).group(1)
            else:
                name = re.search(r"(?m)^Name=(.*)$", read(script)).group(1)
            self.assertIn(name, table[app])


class LanguagePicker(unittest.TestCase):
    """the language is picked from a menu: a row of segments ran out of room at five"""

    def test_language_is_a_dropdown(self):
        page = read("lucidprefs/LanguagePage.qml")
        self.assertIn("M3Dropdown {", page)
        self.assertNotIn("M3Segmented", page)

    def test_every_shipped_catalogue_is_offered(self):
        shipped = sorted(f[:-5] for f in os.listdir(os.path.join(ROOT, "i18n")) if f.endswith(".json"))
        self.assertGreaterEqual(len(shipped), 4)
        for code in shipped:
            meta = json.loads(read(f"i18n/{code}.json"))["_meta"]
            self.assertTrue(meta.get("name"), f"{code}.json has no _meta name to show in the menu")


if __name__ == "__main__":
    unittest.main()
