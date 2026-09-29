#!/usr/bin/env python3
"""Prints the installed Steam library as one JSON object, for the games widget.

Reads only what Steam keeps on disk: the library folders, each app manifest,
every local user's play history and the artwork cache. Nothing is fetched.
"""
import json
import os
import re
import shutil

HOME = os.path.expanduser("~")
FLATPAK_ID = "com.valvesoftware.Steam"
ROOTS = [
    (os.path.join(HOME, ".local/share/Steam"), False),
    (os.path.join(HOME, ".steam/steam"), False),
    (os.path.join(HOME, ".var/app", FLATPAK_ID, ".local/share/Steam"), True),
]
# runtimes and compatibility layers install like games but are not ones
TOOLS = re.compile(
    r"^(Proton\b|Steam Linux Runtime|Steamworks Common Redistributables|SteamVR\b)",
    re.I)
TOKEN = re.compile(r'"((?:[^"\\]|\\.)*)"|([{}])')


def parse_vdf(text):
    root = {}
    stack = [root]
    key = None
    for m in TOKEN.finditer(text):
        word, brace = m.group(1), m.group(2)
        if brace == "{":
            child = {}
            if key is not None:
                stack[-1][key.lower()] = child
            stack.append(child)
            key = None
        elif brace == "}":
            if len(stack) > 1:
                stack.pop()
            key = None
        elif key is None:
            key = word
        else:
            stack[-1][key.lower()] = word.replace("\\\\", "\\")
            key = None
    return root


def read_vdf(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return parse_vdf(f.read())
    except OSError:
        return {}


def dig(node, *keys):
    for k in keys:
        if not isinstance(node, dict):
            return None
        node = node.get(k.lower())
    return node


def to_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def find_root():
    seen = set()
    for path, flatpak in ROOTS:
        if not os.path.isdir(os.path.join(path, "steamapps")):
            continue
        real = os.path.realpath(path)
        if real in seen:
            continue
        seen.add(real)
        return real, flatpak
    return None, False


def libraries(root):
    out = [root]
    folders = dig(read_vdf(os.path.join(root, "steamapps/libraryfolders.vdf")),
                  "libraryfolders") or {}
    for entry in folders.values():
        path = entry.get("path") if isinstance(entry, dict) else None
        if path and os.path.realpath(path) not in [os.path.realpath(p) for p in out]:
            out.append(path)
    return out


def history(root):
    """appid -> (last played, minutes played), the most recent across users."""
    out = {}
    for cfg in sorted(os.listdir(os.path.join(root, "userdata"))
                      if os.path.isdir(os.path.join(root, "userdata")) else []):
        apps = dig(read_vdf(os.path.join(root, "userdata", cfg, "config/localconfig.vdf")),
                   "UserLocalConfigStore", "Software", "Valve", "Steam", "apps") or {}
        for appid, info in apps.items():
            if not isinstance(info, dict):
                continue
            last = to_int(info.get("lastplayed"))
            if last >= out.get(appid, (0, 0))[0]:
                out[appid] = (last, to_int(info.get("playtime")))
    return out


def artwork(root, appid):
    cache = os.path.join(root, "appcache/librarycache")
    found = {}
    # newer clients keep one folder per app with the images in hashed subfolders
    folder = os.path.join(cache, appid)
    if os.path.isdir(folder):
        for dirpath, _dirs, files in os.walk(folder):
            for name in files:
                found.setdefault(name, os.path.join(dirpath, name))

    def pick(*names):
        for name in names:
            if name in found:
                return found[name]
            flat = os.path.join(cache, appid + "_" + name)
            if os.path.isfile(flat):
                return flat
        return ""

    return {
        "capsule": pick("library_600x900.jpg", "library_capsule.jpg"),
        "header": pick("library_header.jpg", "header.jpg"),
        "hero": pick("library_hero.jpg"),
        "logo": pick("logo.png"),
    }


def main():
    root, flatpak = find_root()
    if not root:
        print(json.dumps({"found": False, "launch": [], "games": []}))
        return

    played = history(root)
    games = {}
    for lib in libraries(root):
        apps = os.path.join(lib, "steamapps")
        try:
            names = os.listdir(apps)
        except OSError:
            continue
        for name in names:
            if not (name.startswith("appmanifest_") and name.endswith(".acf")):
                continue
            state = dig(read_vdf(os.path.join(apps, name)), "AppState") or {}
            appid = state.get("appid", "")
            title = state.get("name", "")
            # bit 4 is "fully installed"; anything else is mid-download or broken
            if not appid or not title or not to_int(state.get("stateflags")) & 4:
                continue
            if TOOLS.match(title) or appid in games:
                continue
            last, minutes = played.get(appid, (0, 0))
            game = {
                "id": appid,
                "name": title,
                "lastPlayed": last,
                "playtime": minutes,
                "size": to_int(state.get("sizeondisk")),
            }
            game.update(artwork(root, appid))
            games[appid] = game

    if flatpak:
        launch = ["flatpak", "run", FLATPAK_ID]
    elif shutil.which("steam"):
        launch = ["steam"]
    else:
        launch = ["xdg-open"]

    ordered = sorted(games.values(), key=lambda g: (-g["lastPlayed"], g["name"].lower()))
    print(json.dumps({"found": True, "launch": launch, "games": ordered}))


if __name__ == "__main__":
    main()
