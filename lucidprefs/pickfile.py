#!/usr/bin/env python3
"""pickfile.py - asks the desktop's own file chooser for one path.

usage: pickfile.py [--save] [--title T] [--filter "Label=pat,pat"] [--file PATH]

prints the chosen path and nothing else, and nothing at all when the dialog is
cancelled. the xdg portal comes first, so the chooser is whichever one the
desktop is set to use; zenity and then kdialog stand in when no portal answers.
a filter entry with a "/" in it is a mime type, anything else a glob.

the dialog has no parent window to hang off, so hyprland would tile it.
float-lucid-choosers in hypr/modules/windowrules.lua floats it by title, so a
new title passed here needs adding there too.
"""

import argparse
import os
import shutil
import signal
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

try:
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GLibUnix  # noqa: E402
    signal_add = GLibUnix.signal_add
except (ImportError, ValueError):
    # pygobject before GLibUnix had it on GLib
    signal_add = GLib.unix_signal_add

PORTAL = "org.freedesktop.portal.Desktop"
PORTAL_PATH = "/org/freedesktop/portal/desktop"


# zenity filters by glob only, and globs are case-sensitive there
MIME_GLOBS = {
    "image/jpeg": ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"],
    "image/png": ["*.png", "*.PNG"],
    "image/webp": ["*.webp", "*.WEBP"],
}


class Unavailable(Exception):
    pass


def filters(spec):
    """'Images=image/png,*.jpg' -> the portal's a(sa(us)) shape."""
    if not spec:
        return None
    label, _, pats = spec.partition("=")
    rules = [(1 if "/" in p else 0, p.strip()) for p in pats.split(",") if p.strip()]
    return (label.strip() or "Files", rules)


def portal(args):
    """the portal's answer: a path, "" when cancelled. raises Unavailable."""
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    except GLib.Error as e:
        raise Unavailable(e.message)

    token = "lucidpick%d" % os.getpid()
    who = bus.get_unique_name()[1:].replace(".", "_")
    expected = "%s/request/%s/%s" % (PORTAL_PATH, who, token)
    loop = GLib.MainLoop()
    state = {"path": "", "handle": expected, "sub": None}

    def responded(_c, _s, _p, _i, _sig, params):
        code, results = params.unpack()
        uris = results.get("uris", []) if code == 0 else []
        if uris:
            state["path"] = Gio.File.new_for_uri(uris[0]).get_path() or ""
        loop.quit()

    def watch(path):
        if state["sub"] is not None:
            bus.signal_unsubscribe(state["sub"])
        state["handle"] = path
        # armed before the call, so an answer cannot arrive unheard
        state["sub"] = bus.signal_subscribe(
            PORTAL, "org.freedesktop.portal.Request", "Response", path, None,
            Gio.DBusSignalFlags.NONE, responded)

    watch(expected)

    opts = {"handle_token": GLib.Variant("s", token)}
    flt = filters(args.filter)
    if flt:
        opts["filters"] = GLib.Variant("a(sa(us))", [flt])
        opts["current_filter"] = GLib.Variant("(sa(us))", flt)
    if args.save and args.file:
        folder, name = os.path.split(os.path.abspath(args.file))
        opts["current_name"] = GLib.Variant("s", name)
        opts["current_folder"] = GLib.Variant("ay", os.fsencode(folder) + b"\0")

    method = "SaveFile" if args.save else "OpenFile"
    try:
        reply = bus.call_sync(
            PORTAL, PORTAL_PATH, "org.freedesktop.portal.FileChooser", method,
            GLib.Variant("(ssa{sv})", ("", args.title, opts)),
            GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE, -1, None)
    except GLib.Error as e:
        raise Unavailable(e.message)

    handle = reply.unpack()[0]
    if handle != state["handle"]:
        watch(handle)

    # settings closing kills this process; take the dialog down with it
    def close(*_):
        try:
            bus.call_sync(PORTAL, state["handle"], "org.freedesktop.portal.Request",
                          "Close", None, None, Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass
        loop.quit()
        return GLib.SOURCE_REMOVE

    for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal_add(GLib.PRIORITY_DEFAULT, sig, close)

    loop.run()
    return state["path"]


def zenity(args):
    cmd = ["zenity", "--file-selection", "--title=" + args.title]
    if args.save:
        cmd.append("--save")
        if args.file:
            cmd.append("--filename=" + args.file)
    flt = filters(args.filter)
    if flt:
        globs = []
        for kind, p in flt[1]:
            globs += MIME_GLOBS.get(p, ["*." + p.split("/")[-1]]) if kind == 1 else [p]
        if globs:
            cmd.append("--file-filter=%s | %s" % (flt[0], " ".join(globs)))
    return cmd


def kdialog(args):
    start = args.file or os.path.expanduser("~")
    cmd = ["kdialog", "--title", args.title,
           "--getsavefilename" if args.save else "--getopenfilename", start]
    flt = filters(args.filter)
    if flt:
        cmd.append(" ".join(p for _, p in flt[1]))
    return cmd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--save", action="store_true")
    ap.add_argument("--title", default="Choose a file")
    ap.add_argument("--filter", default="")
    ap.add_argument("--file", default="")
    args = ap.parse_args()

    try:
        path = portal(args)
        if path:
            print(path)
        return 0
    except Unavailable as e:
        why = e.args[0] if e.args else "no answer"

    for name, build in (("zenity", zenity), ("kdialog", kdialog)):
        if shutil.which(name):
            out = subprocess.run(build(args), stdout=subprocess.PIPE,
                                 stderr=subprocess.DEVNULL, text=True)
            path = out.stdout.strip()
            if path:
                print(path)
            return 0

    msg = "no file chooser is available: the xdg portal did not answer (%s) " \
          "and neither zenity nor kdialog is installed" % why
    print("pickfile: " + msg, file=sys.stderr)
    if shutil.which("notify-send"):
        subprocess.run(["notify-send", "-a", "Lucid Settings", "-i", "dialog-error",
                        "Could not open a file chooser",
                        "Install xdg-desktop-portal-gtk or zenity."],
                       stderr=subprocess.DEVNULL)
    return 1


if __name__ == "__main__":
    sys.exit(main())
