#!/usr/bin/env python3
"""scheme-gallery.py — the colour schemes of tinted-theming, for Settings -> Palettes.

    scheme-gallery.py update     download the collection and index it
    scheme-gallery.py status     what is on disk, without downloading

https://github.com/tinted-theming/schemes (MIT) holds a few hundred base16 and
base24 schemes as small YAML files. update fetches the repo as one tarball
from codeload.github.com, which, unlike the GitHub API, has no rate limit for
anonymous use, keeps only base16/*.yaml and base24/*.yaml, and writes
index.json beside them: one entry per scheme with its name, author, variant
and colours, which is all the gallery needs to draw it. Adding a scheme as a
theme is add-theme.py's job, given the file.

Everything lives in ~/.cache/lucid/schemes. Only text is read; nothing
downloaded is ever run. Answers in json on stdout.
"""

import io
import json
import os
import re
import shutil
import sys
import tarfile
import tempfile
import time
import urllib.request
from pathlib import Path

REPO = "tinted-theming/schemes"
BRANCH = "spec-0.11"
URL = f"https://codeload.github.com/{REPO}/tar.gz/refs/heads/{BRANCH}"
DIR = Path.home() / ".cache/lucid/schemes"
INDEX = DIR / "index.json"
SYSTEMS = ("base16", "base24")
FIELD = re.compile(r'^\s*(system|name|author|variant|slug)\s*:\s*["\']?(.*?)["\']?\s*$', re.M)
COLOUR = re.compile(r'^\s*(base[0-9A-Fa-f]{2})\s*:\s*["\']?#?([0-9a-fA-F]{6})["\']?', re.M)


def out(**kw):
    print(json.dumps(kw))


def luminance(hexcol):
    r, g, b = (int(hexcol[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def parse(path, system):
    text = path.read_text(encoding="utf-8", errors="ignore")
    fields = {k: v for k, v in FIELD.findall(text)}
    colours = {k.lower(): "#" + v.lower() for k, v in COLOUR.findall(text)}
    if "base00" not in colours or "base05" not in colours or len(colours) < 16:
        return None
    variant = fields.get("variant", "").lower()
    if variant not in ("dark", "light"):
        # older files leave it out: the background decides
        variant = "light" if luminance(colours["base00"]) > 0.4 else "dark"
    return {
        "id": f"{system}/{path.stem}",
        "system": system,
        "name": fields.get("name") or path.stem,
        "author": fields.get("author", ""),
        "variant": variant,
        "file": str(path),
        # base00..base0F are what the gallery draws; base24 adds eight more
        "colors": [colours.get(f"base{i:02X}".lower(), colours["base00"]) for i in range(16)],
    }


def index_all():
    entries = []
    for system in SYSTEMS:
        for p in sorted((DIR / system).glob("*.yaml")):
            e = parse(p, system)
            if e:
                entries.append(e)
    entries.sort(key=lambda e: (e["name"].lower(), e["system"]))
    data = {"source": f"https://github.com/{REPO}", "updated": int(time.time()), "schemes": entries}
    tmp = INDEX.with_suffix(".tmp")
    tmp.write_text(json.dumps(data))
    os.replace(tmp, INDEX)
    return entries


def update():
    req = urllib.request.Request(URL, headers={"User-Agent": "lucid-scheme-gallery"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            blob = r.read(20 * 1024 * 1024 + 1)
    except OSError as e:
        return out(ok=False, error=f"Could not download the gallery: {e}")
    if len(blob) > 20 * 1024 * 1024:
        return out(ok=False, error="The download was far bigger than the gallery should be.")

    staging = Path(tempfile.mkdtemp(prefix="lucid-schemes-"))
    try:
        with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tar:
            for m in tar.getmembers():
                # <repo>-<branch>/base16/<name>.yaml: a plain file, one level down
                parts = Path(m.name).parts
                if (not m.isfile() or len(parts) != 3 or parts[1] not in SYSTEMS
                        or not parts[2].endswith(".yaml") or parts[2].startswith(".")
                        or m.size > 64 * 1024):
                    continue
                f = tar.extractfile(m)
                if f is None:
                    continue
                dest = staging / parts[1] / parts[2]
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(f.read())
        if not any((staging / s).is_dir() for s in SYSTEMS):
            return out(ok=False, error="The download held no schemes.")
        DIR.mkdir(parents=True, exist_ok=True)
        for s in SYSTEMS:
            shutil.rmtree(DIR / s, ignore_errors=True)
            if (staging / s).is_dir():
                shutil.move(str(staging / s), str(DIR / s))
    except (tarfile.TarError, OSError) as e:
        return out(ok=False, error=f"Could not read the download: {e}")
    finally:
        shutil.rmtree(staging, ignore_errors=True)

    entries = index_all()
    out(ok=True, count=len(entries), updated=int(time.time()))


def status():
    if not INDEX.is_file():
        return out(ok=True, count=0, updated=0)
    try:
        data = json.loads(INDEX.read_text())
    except ValueError:
        return out(ok=True, count=0, updated=0)
    out(ok=True, count=len(data.get("schemes", [])), updated=data.get("updated", 0))


def main(argv):
    if argv == ["update"]:
        update()
    elif argv == ["status"]:
        status()
    else:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv[1:])
