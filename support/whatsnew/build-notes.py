#!/usr/bin/env python3
"""build-notes.py VERSION [--name NAME] [--no-placeholders]

writes lucidnews/Notes.qml, the What's new sheet's content, from that version's
section of CHANGELOG.md, so the sheet and the changelog say the same thing:
the intro, every ### and #### heading, each entry, code blocks, and the
pictures, real <img> tags and the <!-- picture: <img ...> --> slots alike.

markdown inside an entry becomes Qt rich text: **bold**, *italic*, `code` and
[links](url); the sheet styles <code> and <a> to the theme. run it again
whenever the changelog's section changes. a picture not in assets/ yet keeps
its place in the sheet until --no-placeholders, which folds those away.
"""

import argparse
import datetime
import html
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# a badge for each top-level heading; a heading not listed gets "notes"
ICONS = {
    "lucid 2": "auto_awesome",
    "sounds": "graphic_eq",
    "from ciro rivera": "favorite",
    "contributed": "group",
    "performance": "speed",
    "installer": "download",
    "fixed": "build",
    "lock screen": "lock",
    "authentication": "lock",
    "users and accounts": "group",
    "notifications": "notifications",
}

# top-level sections the changelog keeps for itself: how to update is no news
# to someone already reading this in the updated shell
SKIP = {"upgrading"}

IMG = re.compile(r"<img\s[^>]*>")
ATTR = re.compile(r'(\w+)="([^"]*)"')


def rich(md):
    """one entry's markdown as Qt rich text"""
    s = html.escape(md, quote=False)
    codes = []

    def keep(m):
        codes.append(m.group(1))
        return "\x00%d\x00" % (len(codes) - 1)

    s = re.sub(r"`([^`]+)`", keep, s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
    s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<![\s*])\*(?![\w*])", r"<i>\1</i>", s)
    s = re.sub("\x00(\\d+)\x00", lambda m: "<code>" + codes[int(m.group(1))] + "</code>", s)
    return s


def section_of(text, version):
    lines = text.split("\n")
    start = None
    for i, l in enumerate(lines):
        if re.match(r"^## v%s\b" % re.escape(version), l):
            start = i
            break
    if start is None:
        sys.exit("no '## v%s' section in CHANGELOG.md" % version)
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("## "):
            end = j
            break
    return lines[start], lines[start + 1:end]


def parse(body):
    heroes, intro, sections = [], [], []
    cur = None
    skipping = False
    para, item, code = [], None, None

    def flush_para():
        nonlocal para
        if para:
            t = rich(" ".join(x.strip() for x in para))
            if cur is None:
                intro.append(t)
            else:
                cur["intro"] = (cur["intro"] + "<br><br>" if cur["intro"] else "") + t
            para = []

    def flush_item():
        nonlocal item
        if item is not None:
            cur["items"].append({"text": rich(" ".join(x.strip() for x in item)), "code": ""})
            item = None

    for line in body:
        if code is not None:
            if line.startswith("```"):
                cur["items"].append({"text": "", "code": "\n".join(code)})
                code = None
            else:
                code.append(line)
            continue
        if line.startswith("```"):
            flush_para()
            flush_item()
            code = []
            continue
        m = re.match(r"^(###|####)\s+(.*)$", line)
        if m:
            flush_para()
            flush_item()
            title = m.group(2).strip()
            level = 1 if m.group(1) == "###" else 2
            if level == 1:
                skipping = title.lower() in SKIP
            cur = {"level": level, "icon": ICONS.get(title.lower(), "notes"),
                   "title": title, "intro": "", "images": [], "items": []}
            # a skipped section and its #### parts still collect, just nowhere shown
            if not skipping:
                sections.append(cur)
            continue
        img = IMG.search(line)
        if img and (line.lstrip().startswith("<img") or line.lstrip().startswith("<!--")):
            flush_para()
            flush_item()
            attrs = dict(ATTR.findall(img.group(0)))
            pic = {"src": attrs.get("src", ""), "alt": html.unescape(attrs.get("alt", ""))}
            (heroes if cur is None else cur["images"]).append(pic)
            continue
        if line.startswith("- "):
            flush_para()
            flush_item()
            item = [line[2:]]
            continue
        if item is not None and line.startswith("  ") and line.strip():
            item.append(line)
            continue
        if not line.strip():
            flush_para()
            flush_item()
            continue
        if line.lstrip().startswith("<!--"):
            continue
        flush_item()
        para.append(line)
    flush_para()
    flush_item()
    return heroes, "<br><br>".join(intro), sections


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument("--name", default="")
    ap.add_argument("--no-placeholders", action="store_true")
    a = ap.parse_args()

    heading, body = section_of(open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read(), a.version)
    d = re.search(r"(\d{4})-(\d{2})-(\d{2})", heading)
    date = ""
    if d:
        day = datetime.date(int(d.group(1)), int(d.group(2)), int(d.group(3)))
        date = "%d %s %d" % (day.day, day.strftime("%B"), day.year)
    heroes, intro, sections = parse(body)

    js = lambda v: json.dumps(v, ensure_ascii=False, indent=4).replace("\n", "\n    ")
    out = """import QtQuick

// what the What's new sheet says about this release: the version's own section
// of CHANGELOG.md, written out by support/whatsnew/build-notes.py so the two
// never disagree. edit the changelog, then run that again, rather than this file.
// pictures are paths under assets/; one that is not there yet keeps its place
// while `placeholders` is on, and folds away once it is off
QtObject {
    // the sheet opens by itself once, on the first start of a shell whose
    // VERSION file says this
    readonly property string version: %s
    readonly property string name: %s
    readonly property string date: %s
    readonly property bool placeholders: %s
    readonly property var heroes: %s
    readonly property string intro: %s
    readonly property var sections: %s
    // the whole history, every version
    readonly property string fullUrl: "https://github.com/Sn3akyy1/lucid/blob/main/CHANGELOG.md"
}
""" % (json.dumps(a.version), json.dumps(a.name, ensure_ascii=False), json.dumps(date),
       "false" if a.no_placeholders else "true", js(heroes),
       json.dumps(intro, ensure_ascii=False), js(sections))
    path = os.environ.get("NOTES_OUT") or os.path.join(ROOT, "lucidnews", "Notes.qml")
    open(path, "w", encoding="utf-8").write(out)
    items = sum(len(s["items"]) for s in sections)
    print("%s: %d sections, %d entries, %d pictures up top" % (path, len(sections), items, len(heroes)))


if __name__ == "__main__":
    main()
