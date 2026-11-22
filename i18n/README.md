# Translations

One file per language, `i18n/<code>.json`, keyed by the English text in the code.
English has no file. A key whose value is `""` is not translated yet and shows
in English.

```json
{
  "_meta": { "name": "Español", "locale": "es" },
  "Settings": "Ajustes",
  "%1 files": "%1 archivos",
  "%1 word": { "one": "%1 palabra", "other": "%1 palabras" }
}
```

- `%1`..`%9` are the arguments of `I18n.tr("…%1…", x)`; keep them all.
- `I18n.trn("%1 word", "%1 words", n)` has `one` and `other`.
- `I18n.trc("weather", "Clear")` is for one English word with two meanings; its key
  is `weather|Clear`.
- `_meta.locale` is the Qt locale for dates and numbers.

**Add a language:** Settings > Language > Export the template, fill it in, and
import it there (or drop it in `~/.config/lucid/i18n/`). To ship it, put it in
this folder.

**Add a text in the code:** wrap it in `I18n.tr`, then
`python3 support/i18n-check.py --lang es --write` adds the empty key to the
catalogue; run it for every shipped language (es, ru, de, tr) and fill them
in. `--strict` fails on empty ones. `// i18n-skip` marks a string that is
not text to read; `// i18n-dynamic` a first argument that is not a literal.
