#!/usr/bin/env python3
"""Prints a GitHub user's contribution calendar as one JSON object, for the
github widget.

Reads the public page github.com draws the profile's graph from, so it needs
no token: it counts what the profile shows (private contributions too, when
the user lets the profile show them). The last good answer is kept in
~/.cache/lucid, so the card still has something to draw while offline.

    github-contributions.py <user>
"""

import datetime
import html
import json
import os
import re
import sys
import urllib.error
import urllib.request

USER_RE = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$")
CELL_RE = re.compile(r"<td\b[^>]*\bdata-date=\"(\d{4}-\d{2}-\d{2})\"[^>]*>")
ID_RE = re.compile(r"\bid=\"([^\"]+)\"")
LEVEL_RE = re.compile(r"\bdata-level=\"(\d)\"")
TIP_RE = re.compile(r"<tool-tip\b[^>]*\bfor=\"([^\"]+)\"[^>]*>([^<]*)</tool-tip>")
COUNT_RE = re.compile(r"^\s*([\d,]+)\s+contributions?\b")
TOTAL_RE = re.compile(r"id=\"js-contribution-activity-description\"[^>]*>\s*([\d,]+)\s+contributions?", re.S)


def out(obj):
    print(json.dumps(obj, separators=(",", ":")))


def cache_path(user):
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return os.path.join(base, "lucid", "github-" + user.lower() + ".json")


def parse(page):
    counts = {}
    for target, text in TIP_RE.findall(page):
        m = COUNT_RE.match(html.unescape(text))
        counts[target] = int(m.group(1).replace(",", "")) if m else 0

    days = {}
    for m in CELL_RE.finditer(page):
        tag = m.group(0)
        ident = ID_RE.search(tag)
        level = LEVEL_RE.search(tag)
        days[m.group(1)] = (
            counts.get(ident.group(1), 0) if ident else 0,
            int(level.group(1)) if level else 0,
        )
    return [[d, n, lv] for d, (n, lv) in sorted(days.items())]


def streaks(days):
    """the run that reaches today (or yesterday, before today's first
    contribution), and the longest run in the year"""
    current = longest = run = 0
    for _, n, _ in days:
        run = run + 1 if n > 0 else 0
        longest = max(longest, run)
    today = datetime.date.today().isoformat()
    for i in range(len(days) - 1, -1, -1):
        d, n, _ = days[i]
        if n > 0:
            current += 1
        elif d == today and current == 0:
            continue
        else:
            break
    return current, longest


def main():
    user = sys.argv[1].strip() if len(sys.argv) > 1 else ""
    if not USER_RE.match(user):
        out({"ok": False, "user": user, "error": "invalid"})
        return

    req = urllib.request.Request(
        "https://github.com/users/" + user + "/contributions",
        headers={"User-Agent": "lucid-github-widget", "Accept": "text/html"},
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            page = r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        out({"ok": False, "user": user, "error": "notfound" if e.code == 404 else "http"})
        return
    except (urllib.error.URLError, OSError):
        try:
            with open(cache_path(user)) as f:
                cached = json.load(f)
            cached["stale"] = True
            out(cached)
        except (OSError, ValueError):
            out({"ok": False, "user": user, "error": "offline"})
        return

    days = parse(page)
    if not days:
        out({"ok": False, "user": user, "error": "parse"})
        return
    m = TOTAL_RE.search(page)
    total = int(m.group(1).replace(",", "")) if m else sum(n for _, n, _ in days)
    current, longest = streaks(days)
    result = {
        "ok": True,
        "user": user,
        "total": total,
        "streak": current,
        "longest": longest,
        "fetched": int(datetime.datetime.now().timestamp()),
        "days": days,
    }
    try:
        path = cache_path(user)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".tmp", "w") as f:
            json.dump(result, f, separators=(",", ":"))
        os.replace(path + ".tmp", path)
    except OSError:
        pass
    out(result)


if __name__ == "__main__":
    main()
