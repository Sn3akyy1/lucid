#!/usr/bin/env python3
# what each key of the typing block makes in every layout of a keymap, compiled
# by libxkbcommon from the same names hyprland uses, so the on-screen keyboard
# draws and types the layout in use. usage: keymap.py RULES MODEL LAYOUT VARIANT OPTIONS
# prints {"layouts": [{"code", "name", "keys": {"AE01": [level1..level4]}}]}, a
# level being {"c": text, "n": keysym name} plus "m", the combining mark, on a dead key
import ctypes
import json
import sys

KEYS = ["TLDE", "LSGT", "BKSL"] + ["AE%02d" % i for i in range(1, 13)] + ["AD%02d" % i for i in range(1, 13)] \
    + ["AC%02d" % i for i in range(1, 12)] + ["AB%02d" % i for i in range(1, 11)]

# a dead key types its mark on the next letter; alone, or before a letter it
# cannot sit on, it is the spacing form
DEAD = {
    "dead_grave": ("`", "\u0300"), "dead_acute": ("\u00b4", "\u0301"), "dead_circumflex": ("^", "\u0302"),
    "dead_tilde": ("~", "\u0303"), "dead_macron": ("\u00af", "\u0304"), "dead_breve": ("\u02d8", "\u0306"),
    "dead_abovedot": ("\u02d9", "\u0307"), "dead_diaeresis": ("\u00a8", "\u0308"), "dead_abovering": ("\u00b0", "\u030a"),
    "dead_doubleacute": ("\u02dd", "\u030b"), "dead_caron": ("\u02c7", "\u030c"), "dead_cedilla": ("\u00b8", "\u0327"),
    "dead_ogonek": ("\u02db", "\u0328"),
}


class RuleNames(ctypes.Structure):
    _fields_ = [(f, ctypes.c_char_p) for f in ("rules", "model", "layout", "variant", "options")]


def main():
    args = (sys.argv[1:] + [""] * 5)[:5]
    x = ctypes.CDLL("libxkbcommon.so.0")
    x.xkb_context_new.restype = ctypes.c_void_p
    x.xkb_keymap_new_from_names.restype = ctypes.c_void_p
    x.xkb_keymap_new_from_names.argtypes = [ctypes.c_void_p, ctypes.POINTER(RuleNames), ctypes.c_int]
    x.xkb_keymap_key_by_name.restype = ctypes.c_uint32
    x.xkb_keymap_key_by_name.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    x.xkb_keymap_num_layouts.restype = ctypes.c_uint32
    x.xkb_keymap_num_layouts.argtypes = [ctypes.c_void_p]
    x.xkb_keymap_layout_get_name.restype = ctypes.c_char_p
    x.xkb_keymap_layout_get_name.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    x.xkb_keymap_key_get_syms_by_level.restype = ctypes.c_int
    x.xkb_keymap_key_get_syms_by_level.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32,
                                                   ctypes.POINTER(ctypes.POINTER(ctypes.c_uint32))]
    x.xkb_keysym_to_utf32.restype = ctypes.c_uint32
    x.xkb_keysym_to_utf32.argtypes = [ctypes.c_uint32]
    x.xkb_keysym_get_name.argtypes = [ctypes.c_uint32, ctypes.c_char_p, ctypes.c_size_t]

    ctx = x.xkb_context_new(0)
    if not ctx:
        raise SystemExit("no xkb context")
    # empty fields fall back to xkbcommon's defaults, as they do for hyprland
    names = RuleNames(*[a.encode() if a else None for a in args])
    km = x.xkb_keymap_new_from_names(ctx, ctypes.byref(names), 0)
    if not km:
        raise SystemExit("the keymap does not compile")

    codes = [c.strip() for c in args[2].split(",")] if args[2] else ["us"]
    buf = ctypes.create_string_buffer(64)
    out = []
    for li in range(x.xkb_keymap_num_layouts(km)):
        keys = {}
        for name in KEYS:
            kc = x.xkb_keymap_key_by_name(km, name.encode())
            if not kc:
                continue
            levels = []
            for lv in range(4):
                syms = ctypes.POINTER(ctypes.c_uint32)()
                n = x.xkb_keymap_key_get_syms_by_level(km, kc, li, lv, ctypes.byref(syms))
                if n < 1:
                    levels.append(None)
                    continue
                sym = syms[0]
                x.xkb_keysym_get_name(sym, buf, 64)
                sname = buf.value.decode()
                if sname in DEAD:
                    levels.append({"c": DEAD[sname][0], "n": sname, "m": DEAD[sname][1]})
                    continue
                cp = x.xkb_keysym_to_utf32(sym)
                # only printable text: control symbols and unknown dead keys are no use here
                levels.append({"c": chr(cp), "n": sname} if cp >= 0x20 and cp != 0x7f else None)
            if any(levels):
                keys[name] = levels
        lname = x.xkb_keymap_layout_get_name(km, li)
        out.append({
            "code": codes[li] if li < len(codes) else "",
            "name": lname.decode() if lname else "",
            "keys": keys,
        })
    print(json.dumps({"layouts": out}, ensure_ascii=False))


if __name__ == "__main__":
    main()
