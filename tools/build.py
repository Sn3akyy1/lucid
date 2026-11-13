#!/usr/bin/env python3
"""build.py [--repo PATH]

writes the site's pages from tools/pages/*.html. each page source starts with a
one-line JSON comment (title, description, nav, out) and may use:

  {{icon NAME}} {{icon NAME fill}}   a material symbol, from the shell's own table
  {{shape NAME [CLASS] [DEG]}}       a material 3 expressive shape, as the shell draws it
  {{app SLOT [CLASS]}}               an icon from lucid's gravity set, in the site's palette
  {{readme SECTION}}                 a README.md section (## heading), as html
  {{changelog}}                      CHANGELOG.md, every version
  {{version}}

the data comes from the lucid repo (default ~/lucid, or --repo), so the icons,
shapes and words are the shell's own. run it again after editing a page source,
styles.css or script.js need no build.
"""

import argparse
import html
import json
import math
import os
import re
import sys

SITE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GH = "https://github.com/Sn3akyy1/lucid"


# ---------------------------------------------------------------- shell data

def load_js_object(path, var):
    t = open(path, encoding="utf-8").read()
    m = re.search(r"var %s = (\{.*?\});?\s*$" % var, t, re.S | re.M)
    if not m:
        sys.exit("no %s in %s" % (var, path))
    return json.loads(m.group(1).rstrip(";"))


class Shell:
    def __init__(self, repo):
        self.repo = repo
        sym = open(os.path.join(repo, "lucidui", "SymbolPaths.js"), encoding="utf-8").read().split("\n")
        line = next(l for l in sym if l.startswith("var p = "))
        self.symbols = json.loads(line[len("var p = "):].rstrip(";"))
        radii = open(os.path.join(repo, "lucidui", "ShapeRadii.js"), encoding="utf-8").read()
        self.N = int(re.search(r"var N = (\d+)", radii).group(1))
        self.radii = json.loads(re.search(r"var r = (\{.*\});", radii, re.S).group(1))
        icons = json.load(open(os.path.join(repo, "lucidicons", "themes", "gravity.json"), encoding="utf-8"))
        shared = icons.get("paths", {})
        self.slots = {}
        for name, parts in icons["slots"].items():
            for p in parts:
                if "ref" in p:
                    p["d"] = shared.get(p["ref"], "")
            self.slots[name] = parts
        self.version = open(os.path.join(repo, "VERSION"), encoding="utf-8").read().strip()

    # the shell's catmull-rom through the sampled radii (lucidui/Shapes.js)
    def shape(self, name, size=100, rot=0.0, step=2):
        # every other sample is plenty at the sizes a page draws them
        r = (self.radii.get(name) or self.radii["circle"])[::step]
        N, c = len(r), size / 2
        pts = []
        for i in range(N):
            th = i / N * 2 * math.pi + rot
            pts.append((c + c * r[i] * math.cos(th), c + c * r[i] * math.sin(th)))
        d = "M%.2f %.2f" % pts[0]
        for j in range(N):
            p0, p1, p2, p3 = pts[(j - 1) % N], pts[j], pts[(j + 1) % N], pts[(j + 2) % N]
            c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
            c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
            d += "C%.2f %.2f %.2f %.2f %.2f %.2f" % (c1 + c2 + p2)
        return d + "Z"


# lucidicons' tone(): a colour taken to an m3 tone by scaling its luminance
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    v = c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return max(0.0, min(1.0, v))


def _rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def _hex(c):
    return "#%02x%02x%02x" % tuple(round(x * 255) for x in c)


def _y(c):
    r, g, b = (_lin(x) for x in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def _y_at(t):
    return t / 903.2963 if t <= 8 else ((t + 16) / 116) ** 3


def _tone_of(c):
    y = _y(c)
    return 903.2963 * y if y <= 0.008856 else 116 * y ** (1 / 3) - 16


def at_tone(hexc, t):
    c = _rgb(hexc)
    target, y = _y_at(max(0, min(100, t))), _y(c)
    if y <= 0:
        g = _gam(target)
        return _hex([g, g, g])
    k = target / y
    lr, lg, lb = (_lin(x) * k for x in c)
    peak = max(lr, lg, lb)
    if peak > 1:
        lr, lg, lb = lr / peak, lg / peak, lb / peak
        yb = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb
        w = 0 if yb >= 1 else max(0, min(1, (target - yb) / (1 - yb)))
        lr, lg, lb = lr + (1 - lr) * w, lg + (1 - lg) * w, lb + (1 - lb) * w
    return _hex([_gam(lr), _gam(lg), _gam(lb)])


# the brand palette in the dark, for icons drawn before script.js runs
BRAND = {"primary": "#80d4dc", "error": "#ffb4ab", "neutral": "#dee4e4", "container": "#181e1e", "raised": "#212829"}


def tone_fallback(key):
    fam, t = key.rsplit("-", 1)
    t = float(t)
    if fam == "container":
        base = BRAND["raised"]
        return base if t == 25 else at_tone(base, max(0, _tone_of(_rgb(base)) + t - 25))
    return at_tone(BRAND.get(fam, BRAND["neutral"]), t)


# ---------------------------------------------------------------- markdown

def inline(s):
    codes = []

    def keep(m):
        codes.append(m.group(1))
        return "\x00%d\x00" % (len(codes) - 1)

    s = re.sub(r"`([^`]+)`", keep, s)
    s = html.escape(s, quote=False)
    # html the source already carries (<br>, <sub>, <b>) comes back as it was
    s = re.sub(r"&lt;(/?(?:br|sub|b|kbd|code))\s*/?&gt;", r"<\1>", s)
    s = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r'<img src="\2" alt="\1" loading="lazy">', s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", lambda m: '<a href="%s">%s</a>' % (link(m.group(2)), m.group(1)), s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<![\s*])\*(?![\w*])", r"<em>\1</em>", s)
    s = re.sub(r"(?<![\w/])#(\d{2,3})\b", r'<a class="pr" href="%s/pull/\1">#\1</a>' % GH, s)
    s = re.sub(r"(?<![\w/@])@([A-Za-z0-9-]{2,39})\b", r'<a class="who" href="https://github.com/\1">@\1</a>', s)
    s = re.sub("\x00(\\d+)\x00", lambda m: "<code>" + html.escape(codes[int(m.group(1))], quote=False) + "</code>", s)
    return s


def link(href):
    # the repo's own files point at github; its anchors keep working on the site's pages
    if href.startswith("http") or href.startswith("#") or href.startswith("mailto:"):
        return href
    if href.startswith("CHANGELOG.md"):
        return "changelog.html" + href[len("CHANGELOG.md"):].replace("#v121--2026-11-13", "#v1-21")
    return GH + "/blob/main/" + href


def img_src(src):
    m = re.match(r"assets/([a-z0-9-]+)\.webp$", src)
    if m:
        return "assets/screenshots/%s.webp" % m.group(1)
    return src


def md(text, shift=0):
    """the subset of github markdown the readme and changelog use"""
    out, lines, i = [], text.split("\n"), 0
    para, items, kind = [], [], None

    def flush():
        nonlocal para, items, kind
        if para:
            out.append("<p>%s</p>" % inline(" ".join(x.strip() for x in para)))
            para = []
        if items:
            tag = "ol" if kind == "ol" else "ul"
            out.append("<%s>%s</%s>" % (tag, "".join("<li>%s</li>" % inline(" ".join(x)) for x in items), tag))
            items, kind = [], None

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith("```"):
            flush()
            lang = s[3:].strip()
            code = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            out.append('<div class="code"><pre><code data-lang="%s">%s</code></pre>'
                       '<button class="copy" type="button" aria-label="Copy">{{icon content_copy}}</button></div>'
                       % (lang, html.escape("\n".join(code), quote=False)))
            i += 1
            continue
        m = re.match(r"^(#{2,4})\s+(.*)$", line)
        if m:
            flush()
            level = min(6, len(m.group(1)) + shift)
            title = m.group(2).strip()
            out.append('<h%d id="%s">%s</h%d>' % (level, slug(title), inline(title), level))
            i += 1
            continue
        if s.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i + 1].strip()):
            flush()
            head = [c.strip() for c in s.strip("|").split("|")]
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            out.append('<div class="table"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>' % (
                "".join("<th>%s</th>" % inline(c) for c in head),
                "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % inline(c) for c in r) for r in rows)))
            continue
        if s.startswith("> "):
            flush()
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip()[1:].strip())
                i += 1
            alert = re.match(r"\[!(\w+)\]", quote[0]) if quote else None
            cls = "callout " + alert.group(1).lower() if alert else "callout"
            if alert:
                quote = quote[1:]
            out.append('<div class="%s">%s</div>' % (cls, inline(" ".join(quote))))
            continue
        if re.match(r"^<!--", s):
            while i < len(lines) and "-->" not in lines[i]:
                i += 1
            i += 1
            continue
        if s.startswith("<img") or s.startswith("<picture") or s.startswith("<p>") or s.startswith("<div") or s.startswith("</"):
            flush()
            if s.startswith("<img"):
                src = re.search(r'src="([^"]+)"', s).group(1)
                alt = (re.search(r'alt="([^"]*)"', s) or [None, ""])[1]
                out.append('<figure class="shot"><img src="%s" alt="%s" loading="lazy"></figure>' % (img_src(src), alt))
            i += 1
            continue
        lm = re.match(r"^(\s*)(- |\d+\. )(.*)$", line)
        if lm and not lm.group(1):
            if para:
                flush()
            k = "ol" if lm.group(2)[0].isdigit() else "ul"
            if kind and kind != k:
                flush()
            kind = k
            items.append([lm.group(3)])
            i += 1
            continue
        if items and line.startswith("  ") and s:
            items[-1].append(s)
            i += 1
            continue
        if not s:
            flush()
            i += 1
            continue
        if items:
            flush()
        para.append(line)
        i += 1
    flush()
    return "\n".join(out)


def slug(t):
    t = re.sub(r"<[^>]+>", "", t).lower()
    t = re.sub(r"[`*]", "", t)
    t = t.replace(".", "-") if re.match(r"^v\d", t) else t
    t = re.sub(r"[^a-z0-9 -]", "", t)
    t = re.sub(r"\s+", "-", t.strip())
    return re.sub(r"-{2,}", "-", t)


def readme_section(text, name):
    m = re.search(r"^## %s\n(.*?)(?=^## |\Z)" % re.escape(name), text, re.S | re.M)
    if not m:
        sys.exit("README has no section %r" % name)
    body = m.group(1)
    # a <details> block becomes a heading over its content: the site shows it all
    body = re.sub(r"<details>\s*<summary>(.*?)</summary>\s*(?:<br>)?",
                  lambda m: "\n#### " + re.sub(r"<[^>]+>", "", m.group(1)).strip() + "\n", body, flags=re.S)
    body = body.replace("</details>", "")
    return md(body, shift=1)


def changelog(text):
    parts = re.split(r"^## ", text, flags=re.M)[1:]
    out = []
    for n, p in enumerate(parts):
        head, _, body = p.partition("\n")
        m = re.match(r"(v[\d.]+(?:\s+beta)?)\s*[—-]\s*(\S+)", head)
        ver, date = (m.group(1), m.group(2)) if m else (head.strip(), "")
        vid = "v" + ver[1:].split()[0].replace(".", "-")
        inner = md(body, shift=1)
        if n == 0:
            out.append('<article class="release latest" id="%s"><header><span class="ver">%s</span>'
                       '<span class="chip accent">Latest</span><time>%s</time></header>%s</article>' % (vid, ver, date, inner))
        else:
            out.append('<details class="release" id="%s"><summary><span class="ver">%s</span><time>%s</time>'
                       '{{icon expand_more}}</summary>%s</details>' % (vid, ver, date, inner))
    return "\n".join(out)


# ---------------------------------------------------------------- pages

class Page:
    def __init__(self, shell, readme, changes):
        self.shell, self.readme, self.changes = shell, readme, changes
        self.icons, self.tones, self.shapes, self.uid = set(), set(), set(), 0

    def icon(self, name, fill=False):
        if name not in self.shell.symbols:
            sys.exit("no symbol %r in the shell's table" % name)
        self.icons.add((name, fill))
        return '<svg class="i" aria-hidden="true" focusable="false"><use href="#i%s-%s"></use></svg>' % ("f" if fill else "", name)

    def shape(self, name, cls="", deg=0):
        if name not in self.shell.radii:
            sys.exit("no shape %r in the shell's table" % name)
        self.shapes.add(name)
        turn = ' transform="rotate(%s 50 50)"' % deg if float(deg) else ""
        return ('<svg class="shape %s" viewBox="0 0 100 100" aria-hidden="true" focusable="false" data-shape="%s">'
                '<use href="#s-%s"%s></use></svg>' % (cls, name, name, turn))

    def app(self, slot, cls=""):
        parts = self.shell.slots.get(slot)
        if parts is None:
            sys.exit("no icon %r in the gravity set" % slot)
        self.uid += 1
        defs, body = [], []
        for n, p in enumerate(parts):
            d = p.get("d", "")
            if not d:
                continue
            style = []
            if "grad" in p:
                gid = "g%d-%d" % (self.uid, n)
                x1, y1, x2, y2 = p["grad"]
                stops = ""
                for off, key in p["stops"]:
                    self.tones.add(key)
                    stops += '<stop offset="%s" style="stop-color:var(--t-%s)"/>' % (off, key)
                defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
                            % (gid, x1, y1, x2, y2, stops))
                style.append("fill:url(#%s)" % gid)
            elif "fill" in p:
                self.tones.add(p["fill"])
                style.append("fill:var(--t-%s)" % p["fill"])
            if "opacity" in p:
                style.append("opacity:%s" % p["opacity"])
            h = p.get("hover")
            if h:
                style.append("--dx:%s;--dy:%s;--sx:%s;--sy:%s;--rot:%sdeg;transform-origin:%spx %spx"
                             % (h["dx"], h["dy"], h["sx"], h["sy"], h["rot"], h["ox"], h["oy"]))
            body.append('<path class="pt" d="%s" style="%s"/>' % (d, ";".join(style)))
        return ('<svg class="app %s" viewBox="0 0 48 48" aria-hidden="true" focusable="false"><defs>%s</defs>%s</svg>'
                % (cls, "".join(defs), "".join(body)))

    def expand(self, src):
        src = src.replace("{{changelog}}", self.changes)
        src = re.sub(r"\{\{readme ([^}]+)\}\}", lambda m: readme_section(self.readme, m.group(1).strip()), src)
        src = src.replace("{{version}}", self.shell.version)
        for _ in range(2):
            src = re.sub(r"\{\{icon ([a-z0-9_]+)( fill)?\}\}", lambda m: self.icon(m.group(1), bool(m.group(2))), src)
            src = re.sub(r"\{\{shape ([a-zA-Z0-9]+)(?: ([a-z0-9 _-]*?))?(?: (-?\d+))?\}\}",
                         lambda m: self.shape(m.group(1), m.group(2) or "", m.group(3) or 0), src)
            src = re.sub(r"\{\{app ([a-z0-9-]+)(?: ([a-z0-9 _-]+))?\}\}", lambda m: self.app(m.group(1), m.group(2) or ""), src)
        return src

    def sprite(self):
        out = []
        for name, fill in sorted(self.icons):
            d = self.shell.symbols[name][1 if fill else 0]
            out.append('<symbol id="i%s-%s" viewBox="0 0 24 24"><path d="%s"/></symbol>' % ("f" if fill else "", name, d))
        for name in sorted(self.shapes):
            out.append('<symbol id="s-%s" viewBox="0 0 100 100"><path d="%s"/></symbol>' % (name, self.shell.shape(name)))
        return '<svg class="sprite" aria-hidden="true" focusable="false">%s</svg>' % "".join(out)


NAV = [
    ("home", "index.html", "Home", "home"),
    ("tour", "tour.html", "Tour", "photo_library"),
    ("docs", "docs.html", "Docs", "description"),
    ("changelog", "changelog.html", "Changelog", "history"),
    ("support", "support.html", "Support", "chat"),
    ("creator", "creator.html", "About", "person"),
]

MARK = ('<svg class="mark" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><g class="mark-orbit">'
        '<path class="mark-ring" d="M15.92,5.72 A7.4,7.4 0 1 0 18.95,14.53"/>'
        '<path class="mark-dot" d="M20,9.4 A1,1 0 1 0 22,9.4 A1,1 0 1 0 20,9.4 Z"/></g>'
        '<path class="mark-star" d="M12,7.4 C12.598,10.62 13.38,11.402 16.6,12 C13.38,12.598 12.598,13.38 12,16.6 '
        'C11.402,13.38 10.62,12.598 7.4,12 C10.62,11.402 11.402,10.62 12,7.4 Z"/></svg>')

HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{desc}">
<meta name="theme-color" content="#050a0b" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#e6eced" media="(prefers-color-scheme: light)">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Lucid">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:image" content="https://sn3akyy1.github.io/lucid/assets/images/og-image.jpg">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="favicon.ico?v=3" sizes="any">
<link rel="icon" href="assets/images/favicon.svg?v=3" type="image/svg+xml">
<link rel="apple-touch-icon" href="assets/images/apple-touch-icon.png?v=3">
<link rel="manifest" href="site.webmanifest">
<link rel="preload" href="assets/fonts/GoogleSansFlex.woff" as="font" type="font/woff" crossorigin>
<link rel="stylesheet" href="styles.css">
<style>:root{{{tones}}}</style>
<script>(function(){{var d=document.documentElement;try{{var t=localStorage.getItem('lucid-theme'),p=localStorage.getItem('lucid-palette');if(t==='light'||t==='dark')d.setAttribute('data-theme',t);if(p&&p!=='lucid')d.setAttribute('data-palette',p);}}catch(e){{}}d.classList.add('js');if(!matchMedia('(prefers-reduced-motion: reduce)').matches){{d.classList.add('reveal');setTimeout(function(){{if(!window.__lucidReveal)d.classList.remove('reveal');}},2500);}}}})();</script>
<script src="assets/shapes.js" defer></script>
<script src="script.js" defer></script>
</head>
<body data-page="{nav}" data-tones="{tonekeys}">
{sprite}
<a class="skip" href="#main">Skip to content</a>
{bar}
<main id="main">
{body}
</main>
{footer}
</body>
</html>
"""


def bar(page, active):
    links = []
    for key, href, label, ico in NAV:
        cur = ' aria-current="page"' if key == active else ""
        links.append('<a class="ws%s" href="%s"%s><span class="ws-label">%s</span></a>'
                     % (" on" if key == active else "", href, cur, label))
    sheet = "".join('<a class="sheet-row%s" href="%s">%s<span>%s</span></a>'
                    % (" on" if k == active else "", h, page.icon(i), l) for k, h, l, i in NAV)
    return """<header class="bar" id="bar">
  <a class="island brand" href="index.html" aria-label="Lucid home">{mark}<span class="brand-name">Lucid</span><span class="brand-ver">v{ver}</span></a>
  <nav class="island centre workspaces" aria-label="Pages"><span class="ws-pill" aria-hidden="true"></span>{links}</nav>
  <div class="island right">
    <a class="sys stars" href="{gh}/stargazers" aria-label="Stars on GitHub">{star}<span data-stars>332</span></a>
    <button class="sys" type="button" data-panel="palette" aria-expanded="false" aria-controls="palette-panel" aria-label="Palette">{palette}</button>
    <button class="sys" type="button" data-mode aria-label="Light or dark">{dark}</button>
    <button class="sys menu-btn" type="button" aria-expanded="false" aria-controls="sheet" aria-label="Pages">{grid}</button>
  </div>
  <div class="bar-panel" id="palette-panel" hidden>
    <p class="panel-title">Palette</p>
    <p class="panel-blurb">The site wears Lucid's own palettes, the way the shell does.</p>
    <div class="seg" role="group" aria-label="Mode">
      <button type="button" data-set-theme="dark">{check}Dark</button><button type="button" data-set-theme="light">{check}Light</button>
    </div>
    <div class="palettes" data-palettes></div>
  </div>
  <div class="sheet" id="sheet" hidden><p class="panel-title">Lucid</p>{sheet}</div>
</header>""".format(mark=MARK, links="".join(links), grid=page.icon("apps"), gh=GH, star=page.icon("star", True),
                    palette=page.icon("palette"), dark=page.icon("dark_mode") + page.icon("light_mode").replace('class="i"', 'class="i" hidden'),
                    check=page.icon("check"), sheet=sheet, ver=page.shell.version)


def footer(page):
    dock = [
        ("app-code", GH, "Source"),
        ("app-software", GH + "/releases", "Releases"),
        ("app-chat", GH + "/issues", "Issues"),
        ("app-files", "docs.html", "Docs"),
        ("app-lucid-settings", "support.html", "Support"),
    ]
    items = "".join('<a class="dock-item" href="%s" aria-label="%s">%s<span class="tip">%s</span></a>'
                    % (h, n, page.app(s, "dock-icon"), n) for s, h, n in dock)
    return """<footer class="foot">
  <nav class="dock" aria-label="Lucid elsewhere"><a class="dock-item launcher" href="index.html" aria-label="Home">{mark}<span class="tip">Home</span></a><span class="dock-sep"></span>{items}</nav>
  <p class="fine">Lucid {ver} · MIT licence · Built on <a href="https://quickshell.org">Quickshell</a> for <a href="https://hypr.land">Hyprland</a> · <a href="creator.html#credits">Fonts and credits</a></p>
</footer>""".format(mark=MARK, items=items, ver=page.shell.version)


def build(repo):
    shell = Shell(repo)
    readme = open(os.path.join(repo, "README.md"), encoding="utf-8").read()
    changes = changelog(open(os.path.join(repo, "CHANGELOG.md"), encoding="utf-8").read())
    src_dir = os.path.join(SITE, "tools", "pages")
    built = []
    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".html"):
            continue
        raw = open(os.path.join(src_dir, name), encoding="utf-8").read()
        m = re.match(r"<!--(\{.*?\})-->\n", raw, re.S)
        meta = json.loads(m.group(1))
        page = Page(shell, readme, changes)
        body = page.expand(raw[m.end():])
        if meta.get("redirect"):
            out = ('<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Lucid</title>'
                   '<meta http-equiv="refresh" content="0; url=%s"><link rel="canonical" href="%s"></head>'
                   '<body><p><a href="%s">Lucid</a></p></body></html>\n' % ((meta["redirect"],) * 3))
        else:
            b, f = bar(page, meta.get("nav", "")), footer(page)
            tones = ";".join("--t-%s:%s" % (k, tone_fallback(k)) for k in sorted(page.tones))
            out = HEAD.format(title=html.escape(meta["title"]), desc=html.escape(meta["desc"]), nav=meta.get("nav", ""),
                              tonekeys=",".join(sorted(page.tones)), sprite=page.sprite(), bar=b, body=body.strip(),
                              footer=f, tones=tones)
        open(os.path.join(SITE, meta["out"]), "w", encoding="utf-8").write(out)
        built.append(meta["out"])
    # the shapes script.js morphs between, straight from the shell's table
    keep = ["circle", "square", "cookie4", "cookie6", "cookie7", "cookie9", "cookie12", "clover4", "clover8", "sunny",
            "verySunny", "burst", "softBurst", "flower", "puffy", "gem", "pentagon", "pill", "oval", "diamond", "arch",
            "slanted", "fan", "ghostish", "triangle", "clamShell", "arrow", "semiCircle"]
    data = {k: [round(v, 4) for v in shell.radii[k]] for k in keep if k in shell.radii}
    open(os.path.join(SITE, "assets", "shapes.js"), "w", encoding="utf-8").write(
        "// the material 3 expressive shapes, sampled round the centre: lucid's own table (lucidui/ShapeRadii.js)\n"
        "window.LUCID_SHAPES = %s;\n" % json.dumps(data, separators=(",", ":")))
    print("built", " ".join(built))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=os.environ.get("LUCID_REPO", os.path.expanduser("~/lucid")))
    build(ap.parse_args().repo)
