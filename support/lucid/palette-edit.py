#!/usr/bin/env python3
"""palette-edit.py — the palette editor and exporter behind Settings -> Palettes.

    palette-edit.py build <bg> <fg> <primary> <secondary> <tertiary> <error> <dark|light>
        every role Lucid reads, from six key colours
    palette-edit.py save <name> <palette.json|{json}> <dark|light>
        the palette as a theme of your own, in ~/.config/lucid/themes/<id>/
    palette-edit.py export <palette.json> <lucid|base16> <file> [<name>] [<dark|light>]
        the palette written out to share or to use elsewhere: a Lucid palette
        file, which add-theme.py takes back exactly, or base16 YAML

build hands the six colours to lucid_palette.build_palette, the same builder
the importer uses, so an edited palette comes out as complete (and as
readable: a tone that would not read against the background is moved) as an
imported one. Everything answers in json on stdout.
"""

import colorsys
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lucid_palette import CORE_ROLES, at_tone, build_palette, hue_sat, hx, save_theme, tone  # noqa: E402

HOME = os.path.expanduser("~")
THEME_DIR = f"{HOME}/.config/lucid/themes"
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


def out(**kw):
    print(json.dumps(kw))


def fail(msg):
    out(ok=False, error=msg)
    sys.exit(1)


def load(path):
    try:
        # the palette itself, or a file holding it
        pal = json.loads(path) if path.lstrip().startswith("{") else json.load(open(os.path.expanduser(path)))
    except (OSError, ValueError) as e:
        fail(f"Could not read the palette: {e}")
    if not isinstance(pal, dict):
        fail("That is not a palette.")
    pal = {k: v.lower() for k, v in pal.items() if isinstance(v, str) and HEX.match(v)}
    missing = [r for r in CORE_ROLES if r not in pal]
    if missing:
        fail("The palette has no " + ", ".join(missing) + ".")
    return pal


def build(bg, fg, primary, secondary, tertiary, error, mode):
    for c in (bg, fg, primary, secondary, tertiary, error):
        if not HEX.match(c):
            fail(f"{c} is not a colour like #rrggbb.")
    if mode not in ("dark", "light"):
        fail("mode must be dark or light")
    hints = {"primary": primary, "secondary": secondary, "tertiary": tertiary, "error": error}
    return build_palette(bg, fg, [primary, secondary, tertiary, error], hints, mode=mode)


def cmd_build(args):
    if len(args) != 7:
        fail(__doc__.strip())
    out(ok=True, palette=build(*[a.lower() for a in args[:6]], args[6]))


def cmd_save(args):
    if len(args) != 3:
        fail(__doc__.strip())
    name, path, mode = args[0].strip(), args[1], args[2]
    if not name:
        fail("The theme needs a name.")
    if mode not in ("dark", "light"):
        fail("mode must be dark or light")
    out(ok=True, **save_theme(THEME_DIR, name, load(path), mode, source="editor", detected="editor"))


def synth(hue, like):
    """a hue the palette has no role for, at the tone and chroma of `like`"""
    sat = max(0.35, hue_sat(like)[1])
    return hx(at_tone(colorsys.hls_to_rgb(hue / 360, 0.55, sat), tone(like)))


def base16(pal, name):
    """base16 YAML. The slots the importer reads back (base00 background,
    base05 text, base08 error, base0B tertiary, base0C secondary, base0D
    primary) carry those roles, so the file round-trips; base09, base0A and
    base0E, which a Material palette has no role for, are an orange, a yellow
    and a magenta at the primary's tone."""
    dark = tone(pal["surface"]) < 50
    g = pal.get
    slots = {
        "base00": pal["surface"],
        "base01": g("surface_container_low", pal["surface"]),
        "base02": g("surface_container_high", pal["surface"]),
        "base03": g("outline_variant", g("outline", pal["on_surface"])),
        "base04": g("on_surface_variant", pal["on_surface"]),
        "base05": pal["on_surface"],
        "base06": g("inverse_primary", pal["on_surface"]) if not dark else g("on_primary_container", pal["on_surface"]),
        "base07": g("inverse_surface", pal["on_surface"]),
        "base08": pal["error"],
        "base09": synth(30, pal["primary"]),
        "base0A": synth(50, pal["primary"]),
        "base0B": pal["tertiary"],
        "base0C": pal["secondary"],
        "base0D": pal["primary"],
        "base0E": synth(300, pal["primary"]),
        "base0F": g("error_container", pal["error"]),
    }
    lines = ['system: "base16"', f'name: {json.dumps(name)}', 'author: "Lucid"',
             f'variant: "{"dark" if dark else "light"}"', "palette:"]
    lines += [f'  {k}: "{v}"' for k, v in slots.items()]
    return "\n".join(lines) + "\n"


def cmd_export(args):
    if len(args) not in (3, 4, 5):
        fail(__doc__.strip())
    pal = load(args[0])
    fmt, dest = args[1], os.path.expanduser(args[2])
    name = args[3] if len(args) >= 4 and args[3].strip() else "Lucid palette"
    mode = args[4] if len(args) == 5 else ("dark" if tone(pal["surface"]) < 50 else "light")
    if fmt == "lucid":
        text = json.dumps({"lucid": "palette", "name": name, "mode": mode, "palette": pal}, indent=2) + "\n"
    elif fmt == "base16":
        text = base16(pal, name)
    else:
        fail("format must be lucid or base16")
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    try:
        with open(dest, "w") as f:
            f.write(text)
    except OSError as e:
        fail(f"Could not write {dest}: {e}")
    out(ok=True, file=dest, format=fmt)


def main(argv):
    cmds = {"build": cmd_build, "save": cmd_save, "export": cmd_export}
    if not argv or argv[0] not in cmds:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    cmds[argv[0]](argv[1:])


if __name__ == "__main__":
    main(sys.argv[1:])
