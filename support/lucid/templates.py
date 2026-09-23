#!/usr/bin/env python3
"""templates.py — the matugen templates, as Settings -> Theme shows and edits them.

    templates.py list                       what the config holds, and the catalog
    templates.py set <name> on|off          switch a template on or off
    templates.py add <name> <input> <output> [--hook <command>]
    templates.py remove <name>
    templates.py try <input>                render a template with the last colours

Everything answers in json on stdout. ~/.config/matugen/config.toml stays the
user's own file and is edited as text, so comments, order and anything else in
it survive: a template switched off keeps its block, every line of it behind
OFF, which matugen reads as a comment. The config is copied to
config.toml.lucid-backup before each change.

An input given as an http(s) url is downloaded into ~/.config/matugen/templates
first. Templates are text; nothing downloaded is ever run.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from pathlib import Path

HOME = Path.home()
CFG = HOME / ".config/matugen/config.toml"
TEMPLATE_DIR = HOME / ".config/matugen/templates"
STATE = HOME / ".cache/lucid/templates.json"
COLOURS = HOME / ".cache/lucid/colours.json"
OFF = "#lucid-off# "

HEADER = re.compile(r"^\s*\[\[?\s*([^\]]*?)\s*\]\]?\s*(#.*)?$")
TPL = "~/.config/matugen/templates"


def profile(base, pattern):
    """firefox and zen keep their css inside a generated profile dir"""
    root = HOME / base
    if not root.is_dir():
        return None
    found = sorted(p for p in root.glob(pattern) if p.is_dir())
    return found[0] if found else None


def catalog():
    """what the installer can wire, with the same guards: each entry is only
    offered while its app is there. keep in step with install.sh"""
    ff = profile(".mozilla/firefox", "*.default-release")
    zen = profile(".config/zen", "*.Default*")
    starship_hook = 'for sh in fish bash zsh; do pkill -WINCH -x "$sh" 2>/dev/null; done; true'
    entries = [
        ("quickshell", "Lucid's own palette", "quickshell-colors.json", "~/.cache/quickshell/matugen.json", "always", ""),
        ("vscode-raw", "VSCodium and VS Code", "vscode-colors", "~/.cache/matugen/vscode-colors", "always", ""),
        ("vscode-json", "VSCodium and VS Code", "vscode-colors.json", "~/.cache/matugen/vscode-colors.json", "always", ""),
        ("hyprland", "Hyprland borders", "hyprland-colors.lua", "~/.config/hypr/colors.conf", "dir:~/.config/hypr", ""),
        ("kitty", "kitty", "kitty.conf", "~/.config/kitty/matugen-colors.conf", "cmd:kitty",
         "killall -SIGUSR1 kitty 2>/dev/null || true"),
        ("starship", "Starship prompt", "starship-colors.toml", "~/.config/starship.toml", "cmd:starship", starship_hook),
        ("gtk3", "GTK 3 apps", "gtk-colors.css", "~/.config/gtk-3.0/colors.css", "always", ""),
        ("gtk4", "GTK 4 apps", "gtk-colors.css", "~/.config/gtk-4.0/colors.css", "always", ""),
        ("rofi", "rofi", "rofi-colors.rasi", "~/.config/rofi/colors.rasi", "dir:~/.config/rofi", ""),
        ("waybar", "Waybar", "colors.css", "~/.config/waybar/colors.css", "dir:~/.config/waybar", ""),
        ("swaync", "SwayNC", "colors.css", "~/.config/swaync/colors.css", "dir:~/.config/swaync", ""),
        ("wlogout", "wlogout", "colors.css", "~/.config/wlogout/colors.css", "dir:~/.config/wlogout", ""),
        ("ags", "AGS", "ags-colors.scss", "~/.config/ags/style/_colors.scss", "dir:~/.config/ags", ""),
        ("vesktop", "Vesktop (Discord)", "midnight-discord.css", "~/.config/vesktop/themes/midnight-discord.css",
         "dir:~/.config/vesktop", ""),
        ("pywalfox", "Firefox through Pywalfox", "pywalfox-colors.json", "~/.cache/wal/colors.json", "cmd:pywalfox",
         "pywalfox update"),
        ("steam-material", "Steam (Millennium)", "steam-material.css",
         "~/.local/share/Steam/millennium/themes/Material-Theme/css/main/colors/matugen.css",
         "dir:~/.local/share/Steam/millennium/themes/Material-Theme", ""),
        ("firefox-website-colors", "Firefox", "firefox-colors.css",
         str(ff / "chrome/colors.css") if ff else "", "profile" if ff else "never", ""),
        ("zen", "Zen Browser", "zen-userchrome.css",
         str(zen / "chrome/userChrome.css") if zen else "", "profile" if zen else "never", ""),
    ]
    out = []
    for name, app, src, output, guard, hook in entries:
        out.append({
            "name": name,
            "app": app,
            "input": f"{TPL}/{src}",
            "output": output,
            "hook": hook,
            "installed": installed(guard) and (TEMPLATE_DIR / src).is_file(),
            # lucid's own palette: switching it off would leave the shell uncoloured
            "required": name == "quickshell",
        })
    return out


def installed(guard):
    if guard in ("always", "profile"):
        return True
    if guard == "never":
        return False
    kind, _, arg = guard.partition(":")
    if kind == "dir":
        return expand(arg).is_dir()
    if kind == "cmd":
        return shutil.which(arg) is not None
    return False


def expand(path):
    p = Path(os.path.expanduser(path))
    return p if p.is_absolute() else CFG.parent / p


def value(line):
    m = re.match(r"^\s*[\w.-]+\s*=\s*(['\"])(.*?)\1", line)
    return m.group(2) if m else ""


def parse(text):
    """blocks in file order. each: kind (template|other), name, enabled, start,
    end (exclusive), and the template's fields"""
    lines = text.split("\n")
    blocks = []
    cur = {"kind": "other", "name": "", "enabled": True, "start": 0}
    for i, line in enumerate(lines):
        off = line.startswith(OFF)
        raw = line[len(OFF):] if off else line
        m = HEADER.match(raw)
        if not m:
            continue
        cur["end"] = i
        blocks.append(cur)
        key = m.group(1)
        t = re.match(r"^templates\s*\.\s*(?:\"([^\"]*)\"|'([^']*)'|([^.\s]+))", key)
        if t:
            name = t.group(1) if t.group(1) is not None else (t.group(2) if t.group(2) is not None else t.group(3))
            cur = {"kind": "template", "name": name, "enabled": not off, "start": i}
        else:
            cur = {"kind": "other", "name": key, "enabled": not off, "start": i}
    cur["end"] = len(lines)
    blocks.append(cur)

    for b in blocks:
        if b["kind"] != "template":
            continue
        fields = {"input_path": "", "output_path": "", "post_hook": ""}
        for line in lines[b["start"]:b["end"]]:
            raw = line[len(OFF):] if line.startswith(OFF) else line
            k = re.match(r"^\s*(input_path|output_path|post_hook)\s*=", raw)
            if k:
                fields[k.group(1)] = value(raw)
        b.update(fields)
    return lines, blocks


def templates(blocks):
    """a block may be split by a [templates.x.y] table; its name is x"""
    seen = {}
    for b in blocks:
        if b["kind"] != "template":
            continue
        if b["name"] in seen:
            t = seen[b["name"]]
            for k in ("input_path", "output_path", "post_hook"):
                t[k] = t[k] or b[k]
            continue
        seen[b["name"]] = dict(b)
    return list(seen.values())


def read():
    text = CFG.read_text() if CFG.is_file() else ""
    return parse(text)


def write(lines):
    CFG.parent.mkdir(parents=True, exist_ok=True)
    if CFG.is_file():
        shutil.copy2(CFG, CFG.with_name(CFG.name + ".lucid-backup"))
    text = "\n".join(lines)
    fd, tmp = tempfile.mkstemp(dir=CFG.parent, prefix=".lucid-config-")
    with os.fdopen(fd, "w") as f:
        f.write(text)
    os.replace(tmp, CFG)


def fail(message):
    print(json.dumps({"ok": False, "error": message}))
    sys.exit(1)


def done(**extra):
    print(json.dumps({"ok": True, **extra}))


def cmd_list():
    _, blocks = read()
    tpls = templates(blocks)
    cat = catalog()
    by_name = {c["name"]: c for c in cat}
    out = []
    for t in tpls:
        c = by_name.get(t["name"])
        out.append({
            "name": t["name"],
            "app": c["app"] if c else "",
            "input": t["input_path"],
            "inputPath": str(expand(t["input_path"])) if t["input_path"] else "",
            "output": t["output_path"],
            "outputPath": str(expand(t["output_path"])) if t["output_path"] else "",
            "hook": t["post_hook"],
            "enabled": t["enabled"],
            "required": bool(c and c["required"]),
            "bundled": c is not None,
        })
    names = {t["name"] for t in tpls}
    outputs = {str(expand(t["output_path"])) for t in tpls if t["output_path"]}
    offer = [c for c in cat
             if c["installed"] and c["name"] not in names and str(expand(c["output"])) not in outputs]
    print(json.dumps({"config": str(CFG), "exists": CFG.is_file(), "templates": out, "catalog": offer}))


def block_lines(blocks, name):
    """line ranges of every block a template has"""
    ranges = []
    for b in blocks:
        if b["kind"] == "template" and b["name"] == name:
            ranges.append((b["start"], b["end"]))
    return ranges


def cmd_set(name, state):
    if state not in ("on", "off"):
        fail("state must be on or off")
    lines, blocks = read()
    ranges = block_lines(blocks, name)
    if not ranges:
        fail(f"no template named {name}")
    if state == "off" and any(c["name"] == name and c["required"] for c in catalog()):
        fail(f"{name} colours Lucid itself, so it stays on")
    for start, end in ranges:
        last = end
        while last > start and lines[last - 1].strip() in ("", OFF.strip()):
            last -= 1
        for i in range(start, last):
            if state == "off" and not lines[i].startswith(OFF):
                lines[i] = OFF + lines[i]
            elif state == "on" and lines[i].startswith(OFF):
                lines[i] = lines[i][len(OFF):]
    write(lines)
    done(name=name, enabled=state == "on")


def toml_key(name):
    return name if re.fullmatch(r"[A-Za-z0-9_-]+", name) else json.dumps(name)


def toml_str(s):
    return f"'{s}'" if "'" not in s and "\n" not in s else json.dumps(s)


def fetch(url):
    """a template from the web lands next to the bundled ones, under its own name"""
    name = Path(urllib.parse.urlparse(url).path).name or "template"
    TEMPLATE_DIR.mkdir(parents=True, exist_ok=True)
    dest = TEMPLATE_DIR / name
    n = 2
    while dest.exists():
        dest = TEMPLATE_DIR / f"{Path(name).stem}-{n}{Path(name).suffix}"
        n += 1
    req = urllib.request.Request(url, headers={"User-Agent": "lucid-templates"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read(1024 * 1024 + 1)
    if len(data) > 1024 * 1024:
        fail("that file is over 1 MB, which is not a template")
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        fail("that file is not text")
    dest.write_bytes(data)
    return "~/" + str(dest.relative_to(HOME)) if dest.is_relative_to(HOME) else str(dest)


def cmd_add(name, src, output, hook):
    name = name.strip()
    if not name:
        fail("the template needs a name")
    if not re.fullmatch(r"[^\"'\[\]\n.]+", name):
        fail("a name can't hold quotes, brackets or dots")
    lines, blocks = read()
    if block_lines(blocks, name):
        fail(f"there is already a template named {name}")
    if re.match(r"^https?://", src):
        try:
            src = fetch(src)
        except OSError as e:
            fail(f"could not download it: {e}")
    elif not expand(src).is_file():
        fail(f"no file at {src}")
    if not output.strip():
        fail("the template needs a file to write")
    out = expand(output)
    out.parent.mkdir(parents=True, exist_ok=True)
    while lines and lines[-1].strip() == "":
        lines.pop()
    block = ["", f"[templates.{toml_key(name)}]", f"input_path = {toml_str(src)}", f"output_path = {toml_str(output)}"]
    if hook.strip():
        block.append(f"post_hook = {toml_str(hook.strip())}")
    if not lines:
        lines = ["[config]"]
    write(lines + block + [""])
    done(name=name, input=src)


def cmd_remove(name):
    lines, blocks = read()
    ranges = block_lines(blocks, name)
    if not ranges:
        fail(f"no template named {name}")
    if any(c["name"] == name and c["required"] for c in catalog()):
        fail(f"{name} colours Lucid itself, so it stays")
    drop = set()
    for start, end in ranges:
        drop.update(range(start, end))
    kept = [l for i, l in enumerate(lines) if i not in drop]
    while kept and kept[-1].strip() == "":
        kept.pop()
    write(kept + [""])
    done(name=name)


def explain(report):
    """matugen's boxed report down to one line, as render-templates.sh does"""
    text = re.sub(r"\x1b\[[0-9;]*m", "", report)
    msg = ""
    tails = re.findall(r"╰.*─ (.*)$", text, re.M)
    if tails:
        msg = tails[-1].strip()
    if not msg:
        m = re.search(r"^Error: *(.+)$", text, re.M)
        msg = m.group(1).strip() if m else ""
    if not msg:
        msg = " · ".join(re.findall(r"^\s*\d+: (.*)$", text, re.M))
    loc = re.search(r"╭─\[ .*:(\d+):\d+ \]", text)
    if loc:
        msg = f"line {loc.group(1)}: {msg}"
    return msg or "matugen failed"


def cmd_try(src):
    if not COLOURS.is_file():
        fail("change the theme or the wallpaper once first, so there are colours to try it with")
    tmp = Path(tempfile.mkdtemp(prefix="lucid-try-"))
    try:
        if re.match(r"^https?://", src):
            req = urllib.request.Request(src, headers={"User-Agent": "lucid-templates"})
            try:
                with urllib.request.urlopen(req, timeout=20) as r:
                    (tmp / "input").write_bytes(r.read(1024 * 1024))
            except OSError as e:
                fail(f"could not download it: {e}")
            inp = tmp / "input"
        else:
            inp = expand(src)
            if not inp.is_file():
                fail(f"no file at {src}")
        mode = "dark"
        try:
            mode = json.loads(STATE.read_text()).get("mode", "dark")
        except (OSError, ValueError):
            pass
        cfg = tmp / "config.toml"
        cfg.write_text(f"[config]\n\n[templates.try]\ninput_path = {json.dumps(str(inp))}\n"
                       f"output_path = {json.dumps(str(tmp / 'out'))}\n")
        r = subprocess.run(["matugen", "-c", str(cfg), "json", str(COLOURS), "-m", mode],
                           capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            fail(explain(r.stdout + r.stderr))
        out = (tmp / "out").read_text(errors="replace")
        done(text=out[:6000], truncated=len(out) > 6000, lines=out.count("\n") + 1)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main(argv):
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    cmd, args = argv[0], argv[1:]
    if cmd == "list" and not args:
        cmd_list()
    elif cmd == "set" and len(args) == 2:
        cmd_set(args[0], args[1])
    elif cmd == "add" and len(args) in (3, 5) and (len(args) == 3 or args[3] == "--hook"):
        cmd_add(args[0], args[1], args[2], args[4] if len(args) == 5 else "")
    elif cmd == "remove" and len(args) == 1:
        cmd_remove(args[0])
    elif cmd == "try" and len(args) == 1:
        cmd_try(args[0])
    else:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
