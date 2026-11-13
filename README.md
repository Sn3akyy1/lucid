# Lucid website

The website for [Lucid](https://github.com/Sn3akyy1/lucid), published from the `gh-pages`
branch to https://sn3akyy1.github.io/lucid/. Plain HTML, CSS and JavaScript, no framework.
Open `index.html` in a browser to preview it.

It is dressed as Lucid itself, from Lucid's own pieces: the navigation is the shell's bar
(the pages are its workspaces), the hero carries the Poster clock and real widgets telling the
real time, the icons are the shell's Material Symbols and its Gravity icon set, the shapes are
the Material 3 Expressive shapes the shell draws, the sound board plays the shell's own
sounds, and the palettes are the shell's. Surfaces are flat and opaque: no blur, no glow.

## Building

The pages are written by `tools/build.py` from the sources in `tools/pages/`:

```sh
python3 tools/build.py              # reads the lucid repo at ~/lucid
python3 tools/build.py --repo PATH  # or another checkout
```

It takes from the repo: the icons (`lucidui/SymbolPaths.js`), the shapes
(`lucidui/ShapeRadii.js`), the Gravity icons (`lucidicons/themes/gravity.json`), `VERSION`,
and the words of `README.md` (the Docs page) and `CHANGELOG.md` (the Changelog page). Run it
again after a release, or after editing a page source. `styles.css` and `script.js` are
edited by hand and need no build.

A page source starts with a one-line JSON comment (`title`, `desc`, `nav`, `out`, or
`redirect`) and may use `{{icon NAME}}`, `{{icon NAME fill}}`, `{{shape NAME CLASS}}`,
`{{app SLOT CLASS}}`, `{{readme SECTION}}`, `{{changelog}}` and `{{version}}`. The bar and
the footer dock are in `build.py`, so they change on every page at once.

## Pages

| File | What it is |
| --- | --- |
| `index.html` | Home: the headline, live widgets, the ecosystem, the apps, edit mode, lyrics, the sound board, palettes, news and install |
| `tour.html` | The screenshots, with a viewer modelled on Lens (filmstrip, arrow keys) |
| `docs.html` | The README laid out like Settings: a searchable rail and grouped cards, then questions and answers |
| `changelog.html` | Every version from CHANGELOG.md, the newest open |
| `support.html` | A bug report and idea builder that opens a written-out GitHub issue |
| `creator.html` | The creator, live GitHub numbers, the timeline, contributors, the mark and credits |
| `404.html` | Nothing on this workspace |
| `features.html`, `screenshots.html`, `help.html` | Redirects from the old site's pages |

## Layout

```
Lucid/
├── *.html            the pages, written by tools/build.py
├── styles.css        every style, the shell's palettes included
├── script.js         every behaviour
├── tools/            build.py and the page sources
└── assets/
    ├── fonts/        Google Sans Flex (subset, every axis), the Poster figures, Noto Sans Mono, licences
    ├── images/       logo, mark, favicons, app icons, social card
    ├── screenshots/  full-size shots and 960px versions
    ├── sounds/       the shell's sounds, as .ogg and .m4a (for Safari)
    └── shapes.js     the shapes' radii, written by build.py, for the morphs
```

## Releasing

For a new version: copy the new screenshots into `assets/screenshots/` (and 960px
versions), update the hero and the news card in `tools/pages/index.html` and the timeline in
`tools/pages/creator.html`, run `python3 tools/build.py`, then commit and push `gh-pages`.
Pages publishes it in about a minute.
