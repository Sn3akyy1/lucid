#!/usr/bin/env python3
"""Reads and writes the desktop appearance settings that live outside the shell.

Three modes, all printing one JSON object:
  probe            installed cursor/icon/gtk themes and qt styles, plus what
                   gtk2/3/4, gsettings, qt5ct/qt6ct and hyprland currently say
  icons [theme..]  one representative icon path per icon theme, for previews
  apply '<json>'   writes those same eight places

Only the keys Lucid owns are touched; every other setting and every comment in
those files is left where it was.
"""

import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
GTK3 = f"{HOME}/.config/gtk-3.0/settings.ini"
GTK4 = f"{HOME}/.config/gtk-4.0/settings.ini"
GTK2 = f"{HOME}/.gtkrc-2.0"
XCURSOR = f"{HOME}/.icons/default/index.theme"
QT5CT = f"{HOME}/.config/qt5ct/qt5ct.conf"
QT6CT = f"{HOME}/.config/qt6ct/qt6ct.conf"
HYPR_ENV = f"{HOME}/.config/hypr/modules/env.lua"

ICON_DIRS = [f"{HOME}/.icons", f"{HOME}/.local/share/icons", "/usr/share/icons"]
THEME_DIRS = [f"{HOME}/.themes", f"{HOME}/.local/share/themes", "/usr/share/themes"]
QT_BUILTIN_STYLES = ["Fusion", "Windows"]

GSET = "org.gnome.desktop.interface"


def have(cmd):
    return shutil.which(cmd) is not None


def run(args, **kw):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=10, **kw)
    except Exception:
        return None


# ---------------------------------------------------------------- ini editing

def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read().splitlines()
    except OSError:
        return None


def write_lines(path, lines):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".lucid-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")
    os.replace(tmp, path)


def ini_get(path, section, key):
    """the value of key inside section, or None."""
    lines = read_lines(path)
    if lines is None:
        return None
    cur = None
    for ln in lines:
        s = ln.strip()
        if s.startswith("[") and s.endswith("]"):
            cur = s[1:-1]
            continue
        if cur != section or "=" not in s or s.startswith("#") or s.startswith(";"):
            continue
        k, v = s.split("=", 1)
        if k.strip() == key:
            return v.strip()
    return None


def ini_set(path, section, pairs):
    """Set each key of pairs inside section, leaving the rest of the file alone.

    A value of None is skipped, so callers can pass a sparse dict.
    """
    pairs = {k: v for k, v in pairs.items() if v is not None}
    if not pairs:
        return False
    lines = read_lines(path)
    created = lines is None
    if created:
        lines = [f"[{section}]"]

    start = end = None
    for i, ln in enumerate(lines):
        s = ln.strip()
        if s.startswith("[") and s.endswith("]"):
            if start is not None:
                end = i
                break
            if s[1:-1] == section:
                start = i
    if start is None:
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.append(f"[{section}]")
        start = len(lines) - 1
        end = len(lines)
    if end is None:
        end = len(lines)

    left = dict(pairs)
    changed = created
    for i in range(start + 1, end):
        s = lines[i].strip()
        if "=" not in s or s.startswith("#") or s.startswith(";"):
            continue
        k = s.split("=", 1)[0].strip()
        if k in left:
            new = f"{k}={left.pop(k)}"
            if lines[i] != new:
                lines[i] = new
                changed = True

    if left:
        # keep any blank line that separates this section from the next
        at = end
        while at > start + 1 and lines[at - 1].strip() == "":
            at -= 1
        for k, v in left.items():
            lines.insert(at, f"{k}={v}")
            at += 1
        changed = True

    if changed:
        write_lines(path, lines)
    return changed


# ------------------------------------------------------------------ gtk2 rc

GTK2_KEYS = ("gtk-theme-name", "gtk-icon-theme-name", "gtk-font-name",
             "gtk-cursor-theme-name", "gtk-cursor-theme-size")


def gtk2_get(key):
    lines = read_lines(GTK2)
    if lines is None:
        return None
    for ln in lines:
        s = ln.strip()
        if s.startswith("#") or "=" not in s:
            continue
        k, v = s.split("=", 1)
        if k.strip() == key:
            return v.strip().strip('"')
    return None


def gtk2_set(pairs):
    """gtk2's rc file is key=value with quoted strings and no sections."""
    pairs = {k: v for k, v in pairs.items() if v is not None}
    if not pairs:
        return False
    lines = read_lines(GTK2)
    if lines is None:
        lines = []
    left = dict(pairs)
    changed = False
    for i, ln in enumerate(lines):
        s = ln.strip()
        if s.startswith("#") or "=" not in s:
            continue
        k = s.split("=", 1)[0].strip()
        if k in left:
            v = left.pop(k)
            new = f"{k}={v}" if isinstance(v, int) else f'{k}="{v}"'
            if lines[i] != new:
                lines[i] = new
                changed = True
    for k, v in left.items():
        lines.append(f"{k}={v}" if isinstance(v, int) else f'{k}="{v}"')
        changed = True
    if changed:
        write_lines(GTK2, lines)
    return changed


# ----------------------------------------------------------------- hypr env

def lua_env_get(key):
    lines = read_lines(HYPR_ENV)
    if lines is None:
        return None
    pat = re.compile(r'^\s*hl\.env\(\s*"' + re.escape(key) + r'"\s*,\s*"([^"]*)"\s*\)')
    for ln in lines:
        m = pat.match(ln)
        if m:
            return m.group(1)
    return None


def lua_env_set(pairs):
    """Rewrite the hl.env line for each key, or append one that is missing.

    A commented-out line stays commented -- the shipped module keeps several as
    documentation.
    """
    pairs = {k: v for k, v in pairs.items() if v is not None}
    if not pairs:
        return False
    lines = read_lines(HYPR_ENV)
    if lines is None:
        return False  # not our file to create
    left = dict(pairs)
    changed = False
    for i, ln in enumerate(lines):
        for key in list(left):
            pat = re.compile(r'^(\s*)hl\.env\(\s*"' + re.escape(key) + r'"\s*,\s*"[^"]*"\s*\)(.*)$')
            m = pat.match(ln)
            if m:
                new = f'{m.group(1)}hl.env("{key}", "{left.pop(key)}"){m.group(2)}'
                if lines[i] != new:
                    lines[i] = new
                    changed = True
                break
    if left:
        if lines and lines[-1].strip() != "":
            lines.append("")
        lines.append("-- set from lucid settings > environment")
        for k, v in left.items():
            lines.append(f'hl.env("{k}", "{v}")')
        changed = True
    if changed:
        write_lines(HYPR_ENV, lines)
    return changed


# ------------------------------------------------------------------ probing

def dirs_with(sub):
    """theme names under the icon search path that carry a given subdirectory."""
    out = set()
    for d in ICON_DIRS:
        try:
            entries = os.listdir(d)
        except OSError:
            continue
        for name in entries:
            if os.path.isdir(os.path.join(d, name, sub)):
                out.add(name)
    return out


NOSHADOW = "-noshadow"


def cursor_themes():
    """The shadowless rebuilds are variants of a theme, not themes to offer."""
    return sorted((n for n in dirs_with("cursors") if not n.endswith(NOSHADOW)),
                  key=str.lower)


def icon_themes():
    """Anything with an index.theme that is not purely a cursor theme."""
    cursors = dirs_with("cursors")
    out = set()
    for d in ICON_DIRS:
        try:
            entries = os.listdir(d)
        except OSError:
            continue
        for name in entries:
            idx = os.path.join(d, name, "index.theme")
            if not os.path.isfile(idx):
                continue
            if name in cursors or name in ("default", "hicolor"):
                continue
            out.add(name)
    return sorted(out, key=str.lower)


def gtk_themes():
    """A real gtk theme carries a gtk.css; Default and Emacs only bind keys.

    Adwaita is always offered -- libadwaita has it built in and ships no
    directory, so a scan never finds it.
    """
    out = {"Adwaita"}
    for d in THEME_DIRS:
        try:
            entries = os.listdir(d)
        except OSError:
            continue
        for name in entries:
            base = os.path.join(d, name)
            for g in ("gtk-3.0", "gtk-4.0"):
                if any(os.path.isfile(os.path.join(base, g, css))
                       for css in ("gtk.css", "gtk-dark.css")):
                    out.add(name)
                    break
    return sorted(out, key=str.lower)


def qt_styles():
    """The installed style plugins, plus the ones qt always has."""
    found = set(QT_BUILTIN_STYLES)
    for root in ("/usr/lib/qt6/plugins/styles", "/usr/lib/qt/plugins/styles",
                 "/usr/lib/qt5/plugins/styles", f"{HOME}/.local/lib/qt6/plugins/styles"):
        try:
            for f in os.listdir(root):
                if not (f.startswith("lib") and f.endswith(".so")):
                    continue
                name = f[3:-3]
                if name in ("qt5ct-style", "qt6ct-style"):
                    continue
                found.add(name)
        except OSError:
            continue
    if os.path.isdir(f"{HOME}/.config/Kvantum") or shutil.which("kvantummanager"):
        found.add("kvantum")
        found.add("kvantum-dark")
    return sorted(found, key=str.lower)


def theme_dirs(name):
    out = []
    for d in ICON_DIRS:
        base = os.path.join(d, name)
        if os.path.isdir(base):
            out.append(base)
    return out


def theme_inherits(name, seen):
    for base in theme_dirs(name):
        idx = os.path.join(base, "index.theme")
        try:
            with open(idx, encoding="utf-8", errors="replace") as f:
                for ln in f:
                    if ln.strip().lower().startswith("inherits"):
                        parts = ln.split("=", 1)[1].strip().split(",")
                        return [p.strip() for p in parts
                                if p.strip() and p.strip() not in seen]
        except OSError:
            continue
    return []


def _scan_one(theme, want):
    """The biggest file called want anywhere in theme's own directories."""
    best = ""
    best_px = -1
    for base in theme_dirs(theme):
        for root_dir, _dirs, files in os.walk(base):
            for ext in (".svg", ".png"):
                if want + ext not in files:
                    continue
                # scalable first, then the biggest fixed size; symbolic
                # variants are monochrome and make a poor preview
                m = re.search(r"(\d+)x\1", root_dir)
                px = 10000 if ext == ".svg" else (int(m.group(1)) if m else 0)
                if "symbolic" in root_dir:
                    px -= 20000
                if px > best_px:
                    best, best_px = os.path.join(root_dir, want + ext), px
    return best


def find_icon(theme, names, depth=0, seen=None):
    """The first of names that resolves, following Inherits as gtk does."""
    if seen is None:
        seen = set()
    if theme in seen or depth > 4:
        return ""
    seen.add(theme)
    for want in names:
        got = _scan_one(theme, want)
        if got:
            return got
    for parent in theme_inherits(theme, seen):
        got = find_icon(parent, names, depth + 1, seen)
        if got:
            return got
    return ""


PREVIEW_NAMES = ["folder", "user-home", "system-file-manager", "text-x-generic"]


def previews(themes):
    return {t: find_icon(t, PREVIEW_NAMES) for t in themes}


def gsettings_get(key):
    if not have("gsettings"):
        return None
    r = run(["gsettings", "get", GSET, key])
    if not r or r.returncode != 0:
        return None
    v = r.stdout.strip()
    if v.startswith("'") and v.endswith("'"):
        v = v[1:-1]
    return v or None


def font_split(desc):
    """'Google Sans Display 11' -> ('Google Sans Display', 11)"""
    if not desc:
        return ("", 0)
    m = re.match(r"^(.*?)\s+(\d+(?:\.\d+)?)$", desc.strip())
    if not m:
        return (desc.strip(), 0)
    return (m.group(1).strip(), int(float(m.group(2))))


def qfont(family, size):
    """The QFont string qt5ct/qt6ct store fonts as."""
    return f'"{family},{size},-1,5,400,0,0,0,0,0,0,0,0,0,0,1,,0,0"'


def qfont_parse(v):
    if not v:
        return ("", 0)
    v = v.strip().strip('"')
    parts = v.split(",")
    if len(parts) < 2:
        return (v, 0)
    try:
        return (parts[0], int(float(parts[1])))
    except ValueError:
        return (parts[0], 0)


def probe():
    gtk_font = ini_get(GTK3, "Settings", "gtk-font-name") or gsettings_get("font-name")
    fam, size = font_split(gtk_font)
    doc_fam, doc_size = font_split(gsettings_get("document-font-name"))
    mono_fam, mono_size = font_split(gsettings_get("monospace-font-name"))

    # the three disagree often; the hyprland env block is what new clients read
    csize = lua_env_get("XCURSOR_SIZE") or gsettings_get("cursor-size") \
        or ini_get(GTK3, "Settings", "gtk-cursor-theme-size") or "24"
    try:
        csize = int(csize)
    except (TypeError, ValueError):
        csize = 24

    scheme = gsettings_get("color-scheme") or ""
    if scheme.startswith("prefer-"):
        scheme = scheme[len("prefer-"):]
    elif scheme == "default":
        scheme = "auto"

    qt6_style = ini_get(QT6CT, "Appearance", "style")
    qt6_icons = ini_get(QT6CT, "Appearance", "icon_theme")
    qgen_fam, qgen_size = qfont_parse(ini_get(QT6CT, "Fonts", "general"))
    qfix_fam, qfix_size = qfont_parse(ini_get(QT6CT, "Fonts", "fixed"))

    cursor = (lua_env_get("XCURSOR_THEME")
              or gsettings_get("cursor-theme")
              or ini_get(GTK3, "Settings", "gtk-cursor-theme-name") or "")
    shadow = not cursor.endswith(NOSHADOW)
    if not shadow:
        cursor = cursor[:-len(NOSHADOW)]

    return {
        "cursorThemes": cursor_themes(),
        "iconThemes": icon_themes(),
        "gtkThemes": gtk_themes(),
        "qtStyles": qt_styles(),
        "current": {
            "cursorTheme": cursor,
            "cursorShadow": shadow,
            "cursorSize": csize,
            "iconTheme": (gsettings_get("icon-theme")
                          or ini_get(GTK3, "Settings", "gtk-icon-theme-name")
                          or qt6_icons or ""),
            "gtkTheme": (gsettings_get("gtk-theme")
                         or ini_get(GTK3, "Settings", "gtk-theme-name") or ""),
            "qtStyle": qt6_style or "Fusion",
            "qtPlatformTheme": lua_env_get("QT_QPA_PLATFORMTHEME") or "",
            "colorScheme": scheme or "auto",
            "appFont": fam or qgen_fam,
            "appFontSize": size or qgen_size or 11,
            "documentFont": doc_fam or fam,
            "documentFontSize": doc_size or size or 11,
            "monoFont": mono_fam or qfix_fam,
            "monoFontSize": mono_size or qfix_size or 10,
        },
        "targets": {
            "gtk2": os.path.isfile(GTK2),
            "gtk3": os.path.isfile(GTK3),
            "gtk4": os.path.isfile(GTK4),
            "gsettings": have("gsettings"),
            "qt5ct": os.path.isfile(QT5CT),
            "qt6ct": os.path.isfile(QT6CT),
            "hyprland": os.path.isfile(HYPR_ENV),
            "hyprctl": have("hyprctl"),
            "xcursor": True,
        },
    }


# ----------------------------------------------------------------- applying

def apply(cfg):
    scope_gtk = cfg.get("applyGtk", True)
    scope_qt = cfg.get("applyQt", True)
    scope_hypr = cfg.get("applyHypr", True)

    cursor = cfg.get("cursorTheme") or None
    csize = cfg.get("cursorSize") or None
    icons = cfg.get("iconTheme") or None
    gtk = cfg.get("gtkTheme") or None
    scheme = cfg.get("colorScheme") or "auto"
    dark = scheme == "dark"

    app_fam = cfg.get("appFont") or None
    app_size = cfg.get("appFontSize") or 11
    doc_fam = cfg.get("documentFont") or None
    doc_size = cfg.get("documentFontSize") or 11
    mono_fam = cfg.get("monoFont") or None
    mono_size = cfg.get("monoFontSize") or 10
    app_font = f"{app_fam} {app_size}" if app_fam else None

    touched = []

    if scope_gtk:
        common = {
            "gtk-theme-name": gtk,
            "gtk-icon-theme-name": icons,
            "gtk-font-name": app_font,
            "gtk-cursor-theme-name": cursor,
            "gtk-cursor-theme-size": csize,
            "gtk-application-prefer-dark-theme": (1 if dark else 0) if scheme != "auto" else None,
        }
        for path, name in ((GTK3, "gtk3"), (GTK4, "gtk4")):
            if ini_set(path, "Settings", common):
                touched.append(name)
        if gtk2_set({
            "gtk-theme-name": gtk,
            "gtk-icon-theme-name": icons,
            "gtk-font-name": app_font,
            "gtk-cursor-theme-name": cursor,
            "gtk-cursor-theme-size": csize,
        }):
            touched.append("gtk2")

    # what xwayland and plain qt clients read
    if cursor:
        try:
            os.makedirs(os.path.dirname(XCURSOR), exist_ok=True)
            body = ("# written by lucid settings > environment\n"
                    "[Icon Theme]\nName=Default\n"
                    "Comment=Default Cursor Theme\n"
                    f"Inherits={cursor}\n")
            old = ""
            try:
                with open(XCURSOR, encoding="utf-8") as f:
                    old = f.read()
            except OSError:
                pass
            if old != body:
                with open(XCURSOR, "w", encoding="utf-8") as f:
                    f.write(body)
                touched.append("xcursor")
        except OSError:
            pass

    # the live channel: gtk apps and the shell's icon lookup both watch it
    if have("gsettings"):
        gs = {
            "cursor-theme": cursor,
            "icon-theme": icons,
            "font-name": app_font,
            "document-font-name": f"{doc_fam} {doc_size}" if doc_fam else None,
            "monospace-font-name": f"{mono_fam} {mono_size}" if mono_fam else None,
        }
        if scope_gtk:
            gs["gtk-theme"] = gtk
        if csize:
            gs["cursor-size"] = str(csize)
        if scheme != "auto":
            gs["color-scheme"] = "prefer-dark" if dark else "prefer-light"
        wrote = False
        for k, v in gs.items():
            if v is None:
                continue
            run(["gsettings", "set", GSET, k, str(v)])
            wrote = True
        if wrote:
            touched.append("gsettings")

    # only files that already exist; never conjure a config for an unused toolkit
    if scope_qt:
        for path, name in ((QT5CT, "qt5ct"), (QT6CT, "qt6ct")):
            if not os.path.isfile(path):
                continue
            ok = ini_set(path, "Appearance", {
                "icon_theme": icons,
                "style": cfg.get("qtStyle") or None,
            })
            ok |= ini_set(path, "Fonts", {
                "general": qfont(app_fam, app_size) if app_fam else None,
                "fixed": qfont(mono_fam, mono_size) if mono_fam else None,
            })
            if ok:
                touched.append(name)

    # new clients only, and only after a reload
    if scope_hypr:
        env = {"XCURSOR_THEME": cursor, "XCURSOR_SIZE": str(csize) if csize else None}
        if icons:
            env["QS_ICON_THEME"] = icons
        pt = cfg.get("qtPlatformTheme")
        if pt:
            env["QT_QPA_PLATFORMTHEME"] = pt
        if lua_env_set(env):
            touched.append("hyprland")

    if cursor and csize and have("hyprctl"):
        run(["hyprctl", "setcursor", cursor, str(csize)])
        touched.append("hyprctl")

    # gtk clients only repaint when the name changes, so nudge it off and back
    if scope_gtk and gtk and have("gsettings"):
        run(["gsettings", "set", GSET, "gtk-theme", ""])
        run(["gsettings", "set", GSET, "gtk-theme", gtk])

    return {"ok": True, "touched": sorted(set(touched))}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "probe"
    if cmd == "probe":
        json.dump(probe(), sys.stdout)
    elif cmd == "icons":
        want = sys.argv[2:] or icon_themes()
        json.dump(previews(want), sys.stdout)
    elif cmd == "apply":
        raw = (sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()).strip() or "{}"
        try:
            cfg = json.loads(raw)
        except json.JSONDecodeError as e:
            json.dump({"ok": False, "error": f"bad json: {e}"}, sys.stdout)
            return 1
        json.dump(apply(cfg), sys.stdout)
    else:
        json.dump({"ok": False, "error": f"unknown command {cmd}"}, sys.stdout)
        return 1
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
