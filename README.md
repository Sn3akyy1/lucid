# Lucid website

The website for [Lucid](https://github.com/Sn3akyy1/lucid). It is plain HTML, CSS and
JavaScript with no build step and no framework. Open `index.html` in a browser to preview it.

## Pages

| File | What it is |
| --- | --- |
| `index.html` | Home: the hero, a screenshot, what's in Lucid, the palette switcher, install, keybinds |
| `features.html` | Everything in Lucid, section by section |
| `screenshots.html` | The gallery, with a full-size viewer (arrow keys and swipe) |
| `docs.html` | Install, updating, installer options, keybinds, IPC reference, theming, requirements, uninstall |
| `help.html` | Help Center: searchable troubleshooting articles, filtered by topic |
| `support.html` | Support: a bug report and feature request builder that opens a pre-filled GitHub issue, what to include, and how to contribute |
| `changelog.html` | What landed in each release |
| `creator.html` | The creator, how Lucid got here, contributors, and the Lucida mark |
| `404.html` | Not found |

## Layout

```
Lucid/
├── index.html … 404.html   the pages
├── styles.css              every style, including the palettes
├── script.js               every behaviour
├── favicon.ico
├── site.webmanifest
├── robots.txt
└── assets/
    ├── fonts/        Google Sans and Noto Sans Mono (woff2) and their licences
    ├── images/       logo, mark, favicons, app icons, social card
    ├── screenshots/    full-size shots and 960px versions
    └── announcements/  one folder of images per announcement, like v1.1.0/
```

## Where things come from

- **Colours** are the shell's own Material 3 roles. The default is Matugen with the brand
  coral `#FF7F50` as the seed. The other palettes at the bottom of `styles.css` are copied
  colour for colour from `support/lucid/themes/<name>/quickshell.json` and
  `quickshell-light.json` in the Lucid repo. A visitor's choice of palette and of light or
  dark is saved in their browser (`localStorage`, keys `lucid-palette` and `lucid-theme`).
  Every page applies it in its `<head>` before anything is drawn, so nothing flashes the
  default first. Other open tabs of the site follow at once. Until a visitor picks a mode,
  the site follows their system's light or dark.
- **The theme controls** are ports of Lucid's own: the connected Dark/Light button group
  (`M3Segmented.qml`), the Theme page's tiles with each palette's catalogue swatch, the
  grouped setting rows, and the Palette widget. The Theme glyph and the four-point star in
  the header come from the shell (`NavGlyph.qml` and the Lucida mark).
- **Radii, easing and durations** match `Theme.qml`: radii of 8, 12, 16, 20 and 28 px, the
  emphasized decelerate curve `cubic-bezier(0.05, 0.7, 0.1, 1)`, and durations scaled by the
  shell's 1.125 motion baseline.
- **Motion**: headings rise in on load, sections fade up as they scroll into view, a
  palette or mode change spreads from the clicked button in a circle, and pages cross-fade
  where the browser supports View Transitions. Visitors with reduced motion turned on get
  none of it. The scroll reveal is armed by a small script in each page's `<head>`, and it
  shows everything after 2.5 seconds if `script.js` fails to load.
- **Icons** are Material Symbols Rounded (Apache 2.0), inlined into each page as an SVG
  sprite so they also work when a page is opened straight from disk. The GitHub mark is
  from Octicons (MIT).
- **Fonts** are the SIL OFL releases from [google/fonts](https://github.com/google/fonts).
  Keep the `OFL-*.txt` files next to them. Do not swap in the Google Sans files from
  `/usr/share/fonts/TTF`: that older release is not open source.
- **Star and fork counts** come from the GitHub API on every visit, cached for 30 minutes
  per browser tab. The numbers written into the HTML only show if that request fails
  (offline, or past GitHub's 60 requests an hour for one visitor).

## Editing

The header, the mobile menu and the footer are repeated in every page. To change a
navigation link, change it in all nine files.

When a new version ships, update:

- the version chip in every page's header (`brand-ver`, currently `v1.1.0`),
- the news pill on `index.html`,
- `changelog.html`, by adding a new `<article class="release">` at the top and moving the
  "Latest" chip to it,
- the timeline and the "Tagged versions" count on `creator.html`.

## Announcements

The **Announcements** section on the home page is for anything worth telling people:
releases, upcoming updates, notices. Each announcement is two pieces in `index.html`:

1. **A card** in the `#announcements` section, styled like the notification Lucid posts
   when a version lands. Give it `data-ann="<id>"`, set its kind chip (`Release`,
   `Coming soon`, `Notice` and so on), and point its `href` somewhere useful for visitors
   without JavaScript. Put the newest card first, under the "New" label. Older ones go
   under an "Earlier" label with the `is-earlier` class, which drops the tint. Update the
   number in `ann-count`.
2. **A dialog** at the bottom of `<main>`: `<dialog class="ann-dialog" id="ann-<id>">`. Copy
   the v1.1.0 one and change its text and images. Images go in `assets/announcements/<id>/`.

Anything with `data-ann="<id>"` opens that dialog, including the news pill in the hero, so
point that pill at the newest announcement. `index.html#ann-<id>` opens a dialog straight
from a link.

## Deploying

It works on any static host. For GitHub Pages, push this folder to a repository and turn
on Pages for the branch. Two things to fill in once the address is known:

- Social cards need an absolute URL. Change `og:image` in each page's `<head>` from
  `assets/images/og-image.jpg` to the full address, like
  `https://example.github.io/lucid/assets/images/og-image.jpg`.
- `404.html` uses relative links. That works for a missing page at the top level, like
  `/lucid/nope.html`. For a missing page deeper in the path, its styles and links would
  point at the wrong folder. Making its `href`/`src` paths absolute (`/lucid/styles.css`)
  fixes that. Don't use `<base href>` for this: it can break the inline SVG icons.
