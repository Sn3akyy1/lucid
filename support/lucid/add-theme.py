#!/usr/bin/env python3
"""Import a colour-scheme repo as a Lucid theme.

Scheme repos have no common format, so detection is tiered: base16/base24
YAML and name-keyed JSON (Catppuccin and friends) are read exactly, and
anything else falls back to harvesting hex codes and sorting them by tone and
chroma. The exact tiers name the roles they know - which slot is red - so
build_palette does not have to guess them.

Nothing from the repo is ever executed; only text is parsed and only images
are copied.

Writes  ~/.config/lucid/themes/<id>/{quickshell.json,meta.json}
        ~/Pictures/wallpapers/<id>/   (empty is fine - the shell falls back)
Prints  a JSON result for the settings UI.
"""
import json, os, re, shutil, subprocess, sys, tempfile, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lucid_palette import build_palette, describe, tone, hue_sat, hx

HOME = os.path.expanduser('~')
THEME_DIR = f'{HOME}/.config/lucid/themes'
WALL_DIR = f'{HOME}/Pictures/wallpapers'

HEX = re.compile(r'#([0-9a-fA-F]{6})\b')
TEXT_EXT = {'.json', '.yaml', '.yml', '.toml', '.lua', '.css', '.scss', '.conf',
            '.cfg', '.ini', '.txt', '.md', '.xresources', '.itermcolors',
            '.theme', '.colors', '.tmtheme', '.vim', '.el', '.nix'}
IMG_EXT = {'.jpg', '.jpeg', '.png', '.webp'}
SKIP_DIRS = {'.git', 'node_modules', '.github', 'dist', 'build', '__pycache__'}
# the tone nord/tokyo-night/mocha all sit near, used to pick a default variant
IDEAL_BG_TONE = 12.0
GENERIC_REPO = {'palette', 'palettes', 'colors', 'colours', 'theme', 'themes',
                'scheme', 'schemes', 'dotfiles', 'config', 'base16'}

# role name -> the words schemes actually use for it
ROLE_WORDS = {
    'primary':   ['base0d', 'blue', 'sapphire', 'accent', 'cyan'],
    'secondary': ['base0c', 'teal', 'sky', 'mauve', 'purple', 'magenta', 'base0e'],
    'tertiary':  ['base0b', 'green'],
    'error':     ['base08', 'red', 'maroon'],
}
BG_WORDS = ['base00', 'base', 'background', 'bg', 'black']
FG_WORDS = ['base05', 'text', 'foreground', 'fg', 'white']
# surface ladder, darkest first, as base16/Catppuccin name it
LADDER = [('lowest', ['crust', 'mantle']), ('low', ['surface0', 'base01']),
          ('container', ['surface1', 'base02']), ('high', ['surface2', 'base03']),
          ('highest', ['overlay0', 'base04']), ('bright', ['overlay1'])]


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def slug(s):
    s = re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')
    return s or 'theme'


def is_dark(h):
    return tone(h) < 50


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            yield os.path.join(dirpath, f)


# ---- tier 1: base16 / base24 -------------------------------------------
BASE_KEY = re.compile(r'^\s*["\']?(base[0-9A-Fa-f]{2})["\']?\s*[:=]\s*["\']?#?([0-9a-fA-F]{6})',
                      re.M)


def parse_base16(path, text):
    found = {m.group(1).lower(): '#' + m.group(2).lower() for m in BASE_KEY.finditer(text)}
    if len(found) < 8 or 'base00' not in found:
        return None
    name = os.path.splitext(os.path.basename(path))[0]
    m = re.search(r'^\s*(?:scheme|name)\s*[:=]\s*["\']([^"\']+)', text, re.M)
    if m:
        name = m.group(1)
    return {'name': name, 'colors': found, 'kind': 'base16'}


# ---- tier 2: name-keyed JSON (Catppuccin and friends) -------------------
def _flatten_colors(obj):
    """A dict of name -> hex, however the file nests it."""
    out = {}
    if not isinstance(obj, dict):
        return out
    for k, v in obj.items():
        if isinstance(v, str) and HEX.fullmatch(v.strip()):
            out[k.lower()] = v.strip().lower()
        elif isinstance(v, dict):
            h = v.get('hex')
            if isinstance(h, str) and HEX.fullmatch(h.strip()):
                out[k.lower()] = h.strip().lower()
    return out


def parse_named_json(path, text):
    try:
        data = json.loads(text)
    except Exception:
        return []
    schemes = []

    def visit(node, trail):
        if not isinstance(node, dict):
            return
        direct = _flatten_colors(node)
        if len(direct) >= 8:
            schemes.append({'name': node.get('name') or (trail[-1] if trail else
                                                         os.path.basename(path)),
                            'colors': direct, 'kind': 'named-json'})
            return
        for k, v in node.items():
            if isinstance(v, dict):
                sub = _flatten_colors(v.get('colors', v))
                if len(sub) >= 8:
                    schemes.append({'name': v.get('name') or k, 'colors': sub,
                                    'kind': 'named-json'})
                else:
                    visit(v, trail + [k])

    visit(data, [])
    return schemes


# ---- tier 3: harvest ----------------------------------------------------
def harvest(root):
    counts = {}
    for p in walk(root):
        if os.path.splitext(p)[1].lower() not in TEXT_EXT:
            continue
        try:
            if os.path.getsize(p) > 2_000_000:
                continue
            text = open(p, encoding='utf-8', errors='ignore').read()
        except OSError:
            continue
        for m in HEX.finditer(text):
            c = '#' + m.group(1).lower()
            counts[c] = counts.get(c, 0) + 1
    if len(counts) < 6:
        return None
    # a scheme's own colours recur across its templates; one-off hexes in a
    # readme do not, so frequency is the strongest signal of intent here
    ordered = sorted(counts, key=lambda c: -counts[c])[:48]
    return {'name': '', 'colors': {c: c for c in ordered}, 'kind': 'harvest'}


# ---- scheme -> palette inputs ------------------------------------------
def pick(colors, words):
    for w in words:
        if w in colors:
            return colors[w]
    return None


def to_palette(scheme):
    colors = scheme['colors']
    vals = list(dict.fromkeys(colors.values()))
    named = scheme['kind'] != 'harvest'

    bg = pick(colors, BG_WORDS) if named else None
    fg = pick(colors, FG_WORDS) if named else None

    darks = sorted((c for c in vals if is_dark(c)), key=tone)
    lights = sorted((c for c in vals if not is_dark(c)), key=tone, reverse=True)
    if not bg:
        bg = darks[0] if darks else min(vals, key=tone)
    if not fg:
        fg = lights[0] if lights else max(vals, key=tone)

    hints = {}
    if named:
        for role, words in ROLE_WORDS.items():
            c = pick(colors, words)
            if c:
                hints[role] = c
        # A rung is only usable if it actually sits where its role does:
        # everything above `lowest` must be lighter than the surface, or an
        # elevated card would render darker than the page under it.
        surfaces, bt = {}, tone(bg)
        for key, words in LADDER:
            c = pick(colors, words)
            if not c or not is_dark(c):
                continue
            if key == 'lowest' and tone(c) < bt:
                surfaces[key] = c
            elif key != 'lowest' and tone(c) > bt:
                surfaces[key] = c
        if len(surfaces) >= 3:
            hints['surfaces'] = surfaces

    accents = [c for c in vals if hue_sat(c)[1] > 0.12 and 25 < tone(c) < 92]
    if not accents:
        accents = [c for c in vals if c not in (bg, fg)] or vals
    return bg, fg, accents, hints


def detect(root):
    schemes = []
    for p in walk(root):
        ext = os.path.splitext(p)[1].lower()
        if ext not in TEXT_EXT:
            continue
        try:
            if os.path.getsize(p) > 2_000_000:
                continue
            text = open(p, encoding='utf-8', errors='ignore').read()
        except OSError:
            continue
        b = parse_base16(p, text)
        if b:
            schemes.append(b)
        if ext == '.json':
            schemes.extend(parse_named_json(p, text))
    # Dark schemes first - Lucid's surfaces are built for them. The test has
    # to be the scheme's own background: a light flavour still contains dark
    # colours (its text), so "has any dark colour" ranked Latte over Mocha.
    def dark_first(s):
        try:
            bg = to_palette(s)[0]
            # Dark first, then closest to the tone Lucid's own dark themes sit
            # at. Plain "darkest wins" picked pure black out of a 534-scheme
            # collection - technically the darkest, a poor default to land on.
            return (not is_dark(bg), abs(tone(bg) - IDEAL_BG_TONE), -len(s['colors']))
        except Exception:
            return (True, 999.0, 0)
    schemes.sort(key=dark_first)
    if not schemes:
        h = harvest(root)
        if h:
            schemes = [h]
    return schemes


# ---- wallpapers ---------------------------------------------------------
def copy_wallpapers(root, dest):
    """Only images that are plausibly wallpapers. A scheme repo's images are
    usually previews and logos, and importing those as wallpapers would be
    worse than importing none - an empty folder just falls back."""
    imgs = [p for p in walk(root) if os.path.splitext(p)[1].lower() in IMG_EXT]
    wallish = [p for p in imgs
               if re.search(r'wall|background|wallpaper', p, re.I)
               and os.path.getsize(p) > 100_000]
    if not wallish:
        big = [p for p in imgs if os.path.getsize(p) > 300_000]
        # an image-dominated repo is a wallpaper repo
        if len(big) >= 3 and len(big) >= len(list(walk(root))) * 0.25:
            wallish = big
    os.makedirs(dest, exist_ok=True)
    n = 0
    for p in sorted(wallish)[:60]:
        try:
            shutil.copy2(p, os.path.join(dest, os.path.basename(p)))
            n += 1
        except OSError:
            pass
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('url')
    ap.add_argument('--name', default='')
    ap.add_argument('--variant', default='')
    ap.add_argument('--list', action='store_true')
    a = ap.parse_args()

    url = a.url.strip()
    if not re.match(r'^(https?://|git@)[\w.@:/~-]+$', url):
        return fail('That does not look like a git URL.')
    if not shutil.which('git'):
        return fail('git is not installed.')

    with tempfile.TemporaryDirectory() as tmp:
        clone = os.path.join(tmp, 'repo')
        r = run(['git', 'clone', '--depth', '1', '--quiet', url, clone],
                env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'}, timeout=180)
        if r.returncode != 0:
            return fail('Could not clone that repo. ' + r.stderr.strip().split('\n')[-1][:160])

        schemes = detect(clone)
        if not schemes:
            return fail('No colour scheme found in that repo.')

        if a.list:
            print(json.dumps({'ok': True, 'variants': [s['name'] for s in schemes]}))
            return 0

        scheme = schemes[0]
        if a.variant:
            scheme = next((s for s in schemes if s['name'].lower() == a.variant.lower()),
                          scheme)

        bg, fg, accents, hints = to_palette(scheme)
        pal = build_palette(bg, fg, accents, hints,
                            reserve_red_for_error=(scheme['kind'] == 'harvest'))

        parts = re.sub(r'\.git$', '', url.rstrip('/')).replace(':', '/').split('/')
        repo_name = parts[-1]
        owner = parts[-2] if len(parts) > 1 else ''
        if repo_name.lower() in GENERIC_REPO and owner:
            repo_name = owner
        sname = scheme['name']
        label = a.name.strip() or (f'{repo_name} {sname}'
                                   if sname and sname.lower() not in repo_name.lower()
                                   else repo_name)
        tid = slug(label)
        base_id = tid
        n = 2
        while os.path.exists(f'{THEME_DIR}/{tid}'):
            tid = f'{base_id}-{n}'
            n += 1

        os.makedirs(f'{THEME_DIR}/{tid}', exist_ok=True)
        with open(f'{THEME_DIR}/{tid}/quickshell.json', 'w') as f:
            json.dump(pal, f, indent=2)

        walls = copy_wallpapers(clone, f'{WALL_DIR}/{tid}')

        meta = {'id': tid, 'name': label.title(),
                'desc': describe(pal),
                'swatchBg': pal['surface'], 'swatchAccent': pal['primary'],
                'source': url, 'detected': scheme['kind'], 'user': True}
        with open(f'{THEME_DIR}/{tid}/meta.json', 'w') as f:
            json.dump(meta, f, indent=2)

        print(json.dumps({'ok': True, **meta, 'wallpapers': walls,
                          'variants': [s['name'] for s in schemes]}))
    return 0


def fail(msg):
    print(json.dumps({'ok': False, 'error': msg}))
    return 1


if __name__ == '__main__':
    sys.exit(main())
