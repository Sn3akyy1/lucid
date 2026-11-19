#!/usr/bin/env python3
# python3 -m unittest support/tests/i18n/test_check.py -v
import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("i18n_check", os.path.join(HERE, "..", "..", "i18n-check.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class Tree:
    """a fake shell: files given as {relative path: text}, plus i18n/es.json"""

    def __init__(self, files, es=None):
        self.dir = tempfile.mkdtemp()
        for rel, text in files.items():
            p = os.path.join(self.dir, rel)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(p, "w", encoding="utf-8") as f:
                f.write(text)
        cat = {"_meta": {"name": "Español", "locale": "es"}}
        cat.update(es or {})
        os.makedirs(os.path.join(self.dir, "i18n"), exist_ok=True)
        with open(self.catalogue, "w", encoding="utf-8") as f:
            json.dump(cat, f, ensure_ascii=False)

    @property
    def catalogue(self):
        return os.path.join(self.dir, "i18n", "es.json")

    def run(self, *args):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            rc = check.main(["--root", self.dir, "--lang", "es", *args])
        return rc, out.getvalue()


class CheckTest(unittest.TestCase):
    def test_extracts_and_reports_missing(self):
        rc, out = Tree({"a.qml": 'Text { text: I18n.tr("Battery") }\n'}).run()
        self.assertEqual(rc, 1)
        self.assertIn('missing: "Battery"', out)

    def test_unused(self):
        rc, out = Tree({"a.qml": "Item {}\n"}, {"Gone": "Ido"}).run()
        self.assertEqual(rc, 1)
        self.assertIn('unused: "Gone"', out)

    def test_empty_only_strict(self):
        t = Tree({"a.qml": 'Text { text: I18n.tr("Battery") }\n'}, {"Battery": ""})
        self.assertEqual(t.run()[0], 0)
        rc, out = t.run("--strict")
        self.assertEqual(rc, 1)
        self.assertIn('empty: "Battery"', out)

    def test_placeholders(self):
        rc, out = Tree({"a.qml": 'Text { text: I18n.tr("%1 of %2", a, b) }\n'}, {"%1 of %2": "%1 de"}).run()
        self.assertEqual(rc, 1)
        self.assertIn("placeholders", out)

    def test_placeholders_plural(self):
        t = Tree({"a.qml": 'Text { text: I18n.trn("%1 update", "%1 updates", n) }\n'},
                 {"%1 update": {"one": "una actualización", "other": "%1 actualizaciones"}})
        rc, out = t.run()
        self.assertEqual(rc, 1)
        self.assertIn("placeholders", out)

    def test_plural_needs_object(self):
        t = Tree({"a.qml": 'Text { text: I18n.trn("%1 update", "%1 updates", n) }\n'}, {"%1 update": "%1 actualización"})
        rc, out = t.run()
        self.assertEqual(rc, 1)
        self.assertIn("plural", out)

    def test_context_key(self):
        t = Tree({"a.qml": 'Text { text: I18n.trc("verb", "Open") }\n'}, {"verb|Open": "Abrir"})
        self.assertEqual(t.run(), (0, ""))

    def test_nonliteral(self):
        rc, out = Tree({"a.qml": "Text { text: I18n.tr(name) }\n"}).run()
        self.assertEqual(rc, 1)
        self.assertIn("nonliteral", out)
        rc, out = Tree({"a.qml": "Text { text: I18n.tr(name) } // i18n-dynamic\n"}).run()
        self.assertNotIn("nonliteral", out)

    def test_unwrapped(self):
        src = "\n".join([
            'text: "Battery"',
            'title: cond ? "On" : "Off"',
            '"label": "Islands",',
            'text: "°"',
            'text: "Battery" // i18n-skip',
            'text: I18n.tr("Charging")',
        ]) + "\n"
        rc, out = Tree({"a.qml": src}, {"Charging": "Cargando"}).run()
        self.assertEqual(rc, 1)
        self.assertEqual(out.count("unwrapped"), 4, out)
        self.assertIn("a.qml:1:", out)
        self.assertIn("a.qml:3:", out)
        self.assertNotIn("a.qml:4:", out)
        self.assertNotIn("a.qml:5:", out)
        self.assertNotIn("a.qml:6:", out)

    def test_comparison_operands_ignored(self):
        src = 'description: Prefs.look === "objects" ? I18n.tr("Drawn") : "glass" !== mode ? I18n.tr("Glass") : I18n.tr("None")\n'
        t = Tree({"a.qml": src}, {"Drawn": "Dibujado", "Glass": "Vidrio", "None": "Nada"})
        self.assertEqual(t.run(), (0, ""))

    def test_only_the_label_value(self):
        src = '{ "key": "music", "label": "Music", "pref": "specialMusic", "keys": ["Super", "M"] },\n'
        rc, out = Tree({"a.qml": src}).run()
        self.assertEqual(out.count("unwrapped"), 1, out)
        self.assertIn('"Music"', out)

    def test_array_values_are_data(self):
        src = '{ "id": "spotify", "title": ["Spotify", "Spotify Free"] },\n'
        self.assertEqual(Tree({"a.qml": src}).run(), (0, ""))

    def test_subscripts_ignored(self):
        src = '"description": (c.properties || {})["device.description"] || c.name,\n'
        self.assertEqual(Tree({"a.qml": src}).run(), (0, ""))

    def test_more_label_properties(self):
        src = "\n".join([
            'disabledReason: "Turn Bluetooth on first."',
            'placeholder: "Filter by name"',
            'emptyText: "No output devices"',
            '"hint": "Greys only.",',
            '"desc": "Lock screen",',
            '"note": "bar, dock, panels"',
            'tooltip: "Close"',
            'warning: "Frosting is buggy."',
            'unavailableReason: "Tap to click is off."',
            'resetTitle: "Apps under glass"',
            'heading: "Add a keyboard layout"',
        ]) + "\n"
        rc, out = Tree({"a.qml": src}).run()
        self.assertEqual(out.count("unwrapped"), 11, out)

    def test_call_arguments_are_data(self):
        src = 'warning: page.orderWarning("lock")\ndescription: HyprConfig.kbOption("grp") === "x" ? I18n.tr("A") : I18n.tr("B")\n'
        self.assertEqual(Tree({"a.qml": src}, {"A": "a", "B": "b"}).run(), (0, ""))

    def test_translated_label_compared_to_english(self):
        src = "\n".join([
            "function label() { return I18n.tr(\"Lucid's recording\"); }",
            "if (app === \"Lucid's recording\") return;",
        ]) + "\n"
        rc, out = Tree({"a.qml": src}, {"Lucid's recording": "La grabación de Lucid"}).run()
        self.assertEqual(rc, 1)
        self.assertIn("compared: \"Lucid's recording\"", out)

    def test_translated_label_passed_back_as_english(self):
        src = 'onEntered: p.hint = I18n.tr("Dismiss")\nonExited: p.leave("Dismiss")\n'
        rc, out = Tree({"a.qml": src}, {"Dismiss": "Descartar"}).run()
        self.assertIn("compared: \"Dismiss\"", out)

    def test_paths_scope(self):
        t = Tree({"a/x.qml": 'Text { text: I18n.tr("Battery") }\n', "b/x.qml": 'Text { text: "Loose" }\n'}, {"Battery": "Batería"})
        rc, out = t.run(os.path.join(t.dir, "a"))
        self.assertEqual((rc, out), (0, ""))
        rc, out = t.run()
        self.assertIn("unwrapped", out)

    def test_write(self):
        t = Tree({"a.qml": 'Text { text: I18n.tr("Zeta") + I18n.tr("Battery") }\n'}, {"Old": "Viejo"})
        with open(t.catalogue, "w", encoding="utf-8") as f:
            json.dump({"_meta": {"name": "Español", "locale": "es"}, "Old": "Viejo", "Battery": "Batería"}, f)
        rc, out = t.run("--write")
        self.assertIn('unused: "Old"', out)
        with open(t.catalogue, encoding="utf-8") as f:
            text = f.read()
        self.assertEqual(list(json.loads(text)), ["_meta", "Battery", "Zeta"])
        self.assertIn("Batería", text)
        self.assertTrue(text.endswith("}\n"))
        self.assertEqual(t.run()[0], 0)

    def test_write_plural(self):
        t = Tree({"a.qml": 'Text { text: I18n.trn("%1 update", "%1 updates", n) }\n'})
        t.run("--write")
        with open(t.catalogue, encoding="utf-8") as f:
            self.assertEqual(json.load(f)["%1 update"], {"one": "", "other": ""})

    def test_escapes(self):
        t = Tree({"a.qml": 'Text { text: I18n.tr("Say \\"hi\\"") }\n'}, {'Say "hi"': 'Di "hola"'})
        self.assertEqual(t.run(), (0, ""))

    def test_skips_sddm_and_tests(self):
        t = Tree({"support/sddm/x.qml": 'Text { text: "Password" }\n', "support/tests/y.qml": 'Text { text: "Probe" }\n'})
        self.assertEqual(t.run(), (0, ""))


if __name__ == "__main__":
    unittest.main()
