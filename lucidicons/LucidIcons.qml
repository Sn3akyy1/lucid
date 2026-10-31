pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// lucid's own icon sets, for lumen, the desktop, the dock and the launcher: slots
// of parts on the 48 grid, coloured by palette keys. a key like "primary-70" is tone
// 70 of the wallpaper's primary ramp: the live role colour moved to that m3 tone in
// lab, keeping its hue and chroma, and pulled back into srgb when it falls outside.
// a set also says which app is which, by its ids and then by its kind
Singleton {
    id: root

    // every set, in the order a picker lists them; each file is themes/<id>.json
    readonly property var sets: [{
        "id": "gravity",
        "name": "Gravity",
        "blurb": "Soft, top-lit gradients"
    }, {
        "id": "gravity-simplified",
        "name": "Gravity (Simplified)",
        "blurb": "The same icons in flat tones"
    }]
    // the set in use: the shell keeps it on Prefs.envIconSet, lumen on what prefs.json says
    property string set: "gravity"
    // id -> {name, slots, apps, kinds, glyphs}, for each set read so far
    property var _sets: ({})
    property int _read: 0
    readonly property var current: root._sets[root.set] || root._sets["gravity"] || null
    readonly property var slots: root.current ? root.current.slots : ({})
    readonly property var apps: root.current ? root.current.apps : ({})
    readonly property var kinds: root.current ? root.current.kinds : []
    // a place as one bold symbol, [outline, filled] on a 24-unit grid: a folder's
    // is its emblem. for rows too small for the whole icon
    readonly property var glyphs: root.current ? root.current.glyphs : ({})
    readonly property bool loaded: root._read >= root.sets.length
    readonly property string themeName: root.nameOf(root.set)
    // the installed apps as the dock read them, for the categories of an app that
    // only a window class or a pin names
    property var catalog: []
    readonly property var catalogIndex: {
        var idx = ({});
        for (var i = 0; i < root.catalog.length; i++) {
            var a = root.catalog[i];
            var keys = [a.base, a.wmClass, a.name, a.iconName];
            for (var k = 0; k < keys.length; k++) {
                var key = (keys[k] || "").toLowerCase();
                if (key !== "" && idx[key] === undefined)
                    idx[key] = a;

            }
        }
        return idx;
    }
    // what each palette's ramp is built from: the theme's own roles
    readonly property var bases: ({
        "primary": Theme.cPrimary,
        "secondary": Theme.cSecondary,
        "tertiary": Theme.cTertiary,
        "error": Theme.cError,
        "neutral": Theme.cOnSurface,
        "container": Theme.cContainer
    })
    property var _cache: ({})

    // a slot's parts in the set in use, or in the one named, for a preview of it
    function parts(slot, set) {
        var s = set ? (root._sets[set] || root.current) : root.current;
        var all = s ? s.slots : ({});
        return all[slot] || all["file"] || [];
    }

    function nameOf(id) {
        for (var i = 0; i < root.sets.length; i++) {
            if (root.sets[i].id === id)
                return root.sets[i].name;

        }
        return root.sets[0].name;
    }

    function idOf(name) {
        for (var i = 0; i < root.sets.length; i++) {
            if (root.sets[i].name === name)
                return root.sets[i].id;

        }
        return root.sets[0].id;
    }

    function _take(id, text) {
        try {
            var data = JSON.parse(text);
            var shared = data.paths || {};
            var slots = data.slots || {};
            // a part that names a shared path draws it
            for (var s in slots) {
                for (var i = 0; i < slots[s].length; i++) {
                    var p = slots[s][i];
                    if (p.ref !== undefined)
                        p.d = shared[p.ref] || "";

                }
            }
            var all = Object.assign({}, root._sets);
            all[id] = {
                "name": data.name || root.nameOf(id),
                "slots": slots,
                "apps": data.apps || {},
                "kinds": data.kinds || [],
                "glyphs": data.glyphs || {}
            };
            root._sets = all;
        } catch (e) {
            console.warn("lucidicons: icon set " + id + " unreadable: " + e);
        }
        root._read++;
    }

    function has(slot) {
        return slot !== "" && root.slots[slot] !== undefined;
    }

    function tone(key) {
        var i = key.lastIndexOf("-");
        var fam = key.slice(0, i);
        var t = Number(key.slice(i + 1));
        var base = root.bases[fam] || root.bases.neutral;
        var id = fam + base + t;
        var hit = root._cache[id];
        if (hit !== undefined)
            return hit;

        var c = root._atTone(base, t);
        root._cache[id] = c;
        return c;
    }

    // the forms one name of an app takes: itself, its file name, its last dotted
    // part (org.gnome.Nautilus -> nautilus), without a -bin or -browser tail
    function _keys(s) {
        if (!s)
            return [];

        s = String(s).toLowerCase().trim();
        if (s === "")
            return [];

        var out = [s];
        var slash = s.lastIndexOf("/");
        if (slash >= 0) {
            s = s.slice(slash + 1);
            out.push(s);
        }
        var bare = s.replace(/\.(desktop|svg|png|xpm)$/, "");
        if (bare !== s) {
            s = bare;
            out.push(s);
        }
        var dot = s.lastIndexOf(".");
        if (dot > 0 && dot < s.length - 1)
            out.push(s.slice(dot + 1));

        var tail = s.replace(/[-_](bin|browser|desktop|client|app|stable|beta|nightly|git)$/, "");
        if (tail !== s)
            out.push(tail);

        return out;
    }

    // the slot an app gets: the theme's table by its ids, then its first kind the
    // theme draws, or "" for none, when the app keeps its own icon
    function appSlot(id, wmClass, iconName, name, cats) {
        var tries = [].concat(root._keys(id), root._keys(wmClass), root._keys(iconName), root._keys(name));
        for (var i = 0; i < tries.length; i++) {
            var hit = root.apps[tries[i]];
            if (hit && root.slots[hit])
                return hit;

        }
        var c = cats || [];
        if (typeof c === "string")
            c = c.split(/[;\s]+/);

        for (var k = 0; k < root.kinds.length; k++) {
            if (c.indexOf(root.kinds[k][0]) >= 0 && root.slots[root.kinds[k][1]])
                return root.kinds[k][1];

        }
        return "";
    }

    // the same for an app known only by a class, a pin's id or an icon name: the
    // catalog fills in the rest
    function slotFor(key, iconName, name) {
        var idx = root.catalogIndex;
        var e = idx[(key || "").toLowerCase()] || idx[(iconName || "").toLowerCase()] || idx[(name || "").toLowerCase()] || null;
        return root.appSlot(e ? e.base : key, e ? e.wmClass : key, iconName || (e ? e.iconName : ""), name || (e ? e.name : ""), e ? e.cats : []);
    }

    function _lin(c) {
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }

    function _gam(c) {
        return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
    }

    function _f(t) {
        return t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116;
    }

    function _fi(t) {
        var t3 = t * t * t;
        return t3 > 216 / 24389 ? t3 : (116 * t - 16) / (24389 / 27);
    }

    function _rgb(L, a, b) {
        var fy = (L + 16) / 116;
        var x = 0.95047 * root._fi(fy + a / 500);
        var y = L > 8 ? fy * fy * fy : L / (24389 / 27);
        var z = 1.08883 * root._fi(fy - b / 200);
        return [3.2404542 * x - 1.5371385 * y - 0.4985314 * z, -0.969266 * x + 1.8760108 * y + 0.041556 * z, 0.0556434 * x - 0.2040259 * y + 1.0572252 * z];
    }

    function _inGamut(v) {
        return v[0] >= -0.0005 && v[0] <= 1.0005 && v[1] >= -0.0005 && v[1] <= 1.0005 && v[2] >= -0.0005 && v[2] <= 1.0005;
    }

    function _atTone(c, t) {
        var r = root._lin(c.r), g = root._lin(c.g), b = root._lin(c.b);
        var x = root._f((0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047);
        var y = root._f(0.2126729 * r + 0.7151522 * g + 0.072175 * b);
        var z = root._f((0.0193339 * r + 0.119192 * g + 0.9503041 * b) / 1.08883);
        var A = 500 * (x - y), B = 200 * (y - z);
        var v = root._rgb(t, A, B);
        if (!root._inGamut(v)) {
            // the largest chroma at this tone that srgb can still show
            var lo = 0, hi = 1;
            for (var i = 0; i < 14; i++) {
                var mid = (lo + hi) / 2;
                if (root._inGamut(root._rgb(t, A * mid, B * mid)))
                    lo = mid;
                else
                    hi = mid;
            }
            v = root._rgb(t, A * lo, B * lo);
        }
        return Qt.rgba(root._gam(Math.max(0, Math.min(1, v[0]))), root._gam(Math.max(0, Math.min(1, v[1]))), root._gam(Math.max(0, Math.min(1, v[2]))), 1);
    }

    Instantiator {
        model: root.sets

        delegate: FileView {
            required property var modelData

            path: Qt.resolvedUrl("themes/" + modelData.id + ".json").toString().replace("file://", "")
            blockLoading: true
            onLoaded: root._take(modelData.id, text())
            onLoadFailed: root._read++
        }

    }

}
