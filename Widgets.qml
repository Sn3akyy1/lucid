import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    property bool loaded: false
    // set when the file on disk predates the board covering the whole output
    property bool needsLift: false
    property int nextId: 1
    property int topZ: 1
    // the primary layer reports its size here so spawn() can place a card sensibly
    property real canvasW: 1920
    property real canvasH: 1080
    readonly property int count: instances.count
    // one mask slot per widget on each layer, so the desktop holds this many
    readonly property int capacity: 20
    readonly property bool full: instances.count >= root.capacity
    readonly property alias model: instances
    // uid of the widget currently taking keystrokes, if any
    property string editUid: ""
    // uid of the card currently held by the pointer, and of the one showing its menu
    property string dragUid: ""
    property string menuUid: ""

    signal spawned(string uid)

    // the layer covers the whole output, so a card can be dragged under the bar or
    // the dock on purpose. a freshly spawned one should still land clear of them:
    // these mirror the two windows' own exclusive zones
    readonly property real spawnTop: Prefs.barEnabled ? Prefs.effectiveBarTopMargin + Prefs.barHeight : 0
    readonly property real spawnBottom: (Prefs.dockEnabled && !Prefs.dockAutoHide) ? Prefs.dockIconSize + 20 + Prefs.effectiveDockBottomMargin : 0

    // one entry per category; a variant is another face on the same data, not another widget
    readonly property var catalogue: [{
        "id": "clock",
        "name": "Clock",
        "blurb": "The time, in as much or as little detail as you want it.",
        "variants": [{
            "id": "digital",
            "name": "Digital",
            "blurb": "Time over the date, weighted like a headline.",
            "w": 280,
            "h": 148
        }, {
            "id": "stack",
            "name": "Stacked",
            "blurb": "Hour above minute, the way the bar draws it.",
            "w": 220,
            "h": 236
        }, {
            "id": "analog",
            "name": "Analog",
            "blurb": "Hands and ticks. Turn on seconds for a sweep.",
            "w": 212,
            "h": 212
        }, {
            "id": "minimal",
            "name": "Minimal",
            "blurb": "One line of time, no container behind it.",
            "w": 260,
            "h": 96
        }, {
            "id": "world",
            "name": "World",
            "blurb": "Three cities at once, with their offsets.",
            "w": 264,
            "h": 200
        }],
        "options": [{
            "key": "hourMode",
            "label": "Hours",
            "type": "choice",
            "def": "auto",
            "choices": [{
                "key": "auto",
                "label": "Shell"
            }, {
                "key": "12",
                "label": "12"
            }, {
                "key": "24",
                "label": "24"
            }]
        }, {
            "key": "seconds",
            "label": "Show seconds",
            "type": "bool",
            "def": false
        }, {
            "key": "showDate",
            "label": "Show the date",
            "type": "bool",
            "def": true
        }, {
            "key": "accentTime",
            "label": "Tint the time",
            "type": "bool",
            "def": false
        }, {
            "key": "zones",
            "label": "Cities",
            "type": "choice",
            "def": "eu",
            "variants": ["world"],
            "choices": [{
                "key": "eu",
                "label": "Europe"
            }, {
                "key": "us",
                "label": "Americas"
            }, {
                "key": "asia",
                "label": "Asia"
            }]
        }]
    }, {
        "id": "calendar",
        "name": "Calendar",
        "blurb": "Where you are in the month, at a glance.",
        "variants": [{
            "id": "month",
            "name": "Month",
            "blurb": "The full grid, today marked.",
            "w": 300,
            "h": 306
        }, {
            "id": "week",
            "name": "Week",
            "blurb": "Seven days on a strip.",
            "w": 300,
            "h": 132
        }, {
            "id": "today",
            "name": "Today",
            "blurb": "One enormous date and its weekday.",
            "w": 200,
            "h": 200
        }],
        "options": [{
            "key": "mondayFirst",
            "label": "Week starts Monday",
            "type": "bool",
            "def": true
        }, {
            "key": "showMonthName",
            "label": "Show the month",
            "type": "bool",
            "def": true
        }]
    }, {
        "id": "system",
        "name": "System",
        "blurb": "Processor, memory and disk while you work.",
        "variants": [{
            "id": "rings",
            "name": "Rings",
            "blurb": "One arc gauge per metric.",
            "w": 292,
            "h": 158
        }, {
            "id": "bars",
            "name": "Meters",
            "blurb": "Labelled bars stacked in a column.",
            "w": 268,
            "h": 194
        }, {
            "id": "graph",
            "name": "Graph",
            "blurb": "Two minutes of history, drawn.",
            "w": 308,
            "h": 186
        }, {
            "id": "compact",
            "name": "Compact",
            "blurb": "Just the numbers, in a row.",
            "w": 216,
            "h": 90
        }],
        "options": [{
            "key": "showCpu",
            "label": "Processor",
            "type": "bool",
            "def": true
        }, {
            "key": "showRam",
            "label": "Memory",
            "type": "bool",
            "def": true
        }, {
            "key": "showDisk",
            "label": "Disk",
            "type": "bool",
            "def": true
        }, {
            "key": "showTemp",
            "label": "Temperature",
            "type": "bool",
            "def": false
        }, {
            "key": "interval",
            "label": "Refresh",
            "type": "choice",
            "def": "2",
            "choices": [{
                "key": "1",
                "label": "1s"
            }, {
                "key": "2",
                "label": "2s"
            }, {
                "key": "5",
                "label": "5s"
            }]
        }]
    }, {
        "id": "battery",
        "name": "Battery",
        "blurb": "Charge, and how long it has left.",
        "variants": [{
            "id": "ring",
            "name": "Ring",
            "blurb": "An arc that fills as it charges.",
            "w": 176,
            "h": 176
        }, {
            "id": "bar",
            "name": "Bar",
            "blurb": "A cell drawn side on.",
            "w": 248,
            "h": 118
        }, {
            "id": "detail",
            "name": "Detail",
            "blurb": "Charge, state, time left and draw.",
            "w": 268,
            "h": 164
        }],
        "options": [{
            "key": "showTime",
            "label": "Time remaining",
            "type": "bool",
            "def": true
        }, {
            "key": "warnLow",
            "label": "Turn red under 20%",
            "type": "bool",
            "def": true
        }]
    }, {
        "id": "media",
        "name": "Media",
        "blurb": "Whatever is playing, with its artwork.",
        "variants": [{
            "id": "card",
            "name": "Card",
            "blurb": "Artwork above the title and controls.",
            "w": 288,
            "h": 435
        }, {
            "id": "row",
            "name": "Row",
            "blurb": "Artwork beside the title and controls.",
            "w": 330,
            "h": 118
        }, {
            "id": "art",
            "name": "Artwork",
            "blurb": "The cover, with controls over it on hover.",
            "w": 244,
            "h": 244
        }],
        "options": [{
            "key": "showProgress",
            "label": "Progress bar",
            "type": "bool",
            "def": true
        }, {
            "key": "scroll",
            "label": "Scroll long titles",
            "type": "bool",
            "def": true
        }]
    }, {
        "id": "visualiser",
        "name": "Visualiser",
        "blurb": "Whatever is coming out of your speakers, drawn.",
        "variants": [{
            "id": "bars",
            "name": "Bars",
            "blurb": "Columns off the baseline. Stretch it the width of the screen.",
            "w": 720,
            "h": 140,
            "resizable": true,
            "minW": 120,
            "minH": 36,
            "maxW": 5120,
            "maxH": 900
        }, {
            "id": "mirror",
            "name": "Mirror",
            "blurb": "The same bands, opened out from a centre line.",
            "w": 640,
            "h": 160,
            "resizable": true,
            "minW": 120,
            "minH": 40,
            "maxW": 5120,
            "maxH": 900
        }, {
            "id": "wave",
            "name": "Wave",
            "blurb": "One filled curve instead of separate bars.",
            "w": 560,
            "h": 150,
            "resizable": true,
            "minW": 120,
            "minH": 40,
            "maxW": 5120,
            "maxH": 900
        }],
        "options": [{
            "key": "density",
            "label": "Detail",
            "type": "choice",
            "def": "normal",
            "choices": [{
                "key": "wide",
                "label": "Coarse"
            }, {
                "key": "normal",
                "label": "Normal"
            }, {
                "key": "fine",
                "label": "Fine"
            }]
        }, {
            "key": "tint",
            "label": "Colour",
            "type": "choice",
            "def": "accent",
            "choices": [{
                "key": "accent",
                "label": "Accent"
            }, {
                "key": "gradient",
                "label": "Gradient"
            }, {
                "key": "mono",
                "label": "White"
            }]
        }, {
            "key": "frost",
            "label": "Frosted bars",
            "type": "bool",
            "def": true
        }, {
            "key": "rounded",
            "label": "Rounded tips",
            "type": "bool",
            "def": true,
            "variants": ["bars", "mirror"]
        }, {
            "key": "flip",
            "label": "Hang from the top",
            "type": "bool",
            "def": false,
            "variants": ["bars", "wave"]
        }, {
            "key": "idleFade",
            "label": "Hide when silent",
            "type": "bool",
            "def": true
        }]
    }, {
        "id": "weather",
        "name": "Weather",
        "blurb": "Conditions now and over the next few days.",
        "variants": [{
            "id": "current",
            "name": "Current",
            "blurb": "Temperature, condition and the feel of it.",
            "w": 264,
            "h": 168
        }, {
            "id": "forecast",
            "name": "Forecast",
            "blurb": "Today plus the next three days.",
            "w": 320,
            "h": 232
        }, {
            "id": "compact",
            "name": "Compact",
            "blurb": "An icon and a number.",
            "w": 196,
            "h": 96
        }],
        "options": [{
            "key": "units",
            "label": "Units",
            "type": "choice",
            "def": "metric",
            "choices": [{
                "key": "metric",
                "label": "°C"
            }, {
                "key": "imperial",
                "label": "°F"
            }]
        }]
    }, {
        "id": "notes",
        "name": "Notes",
        "blurb": "A scrap of paper that survives a reboot.",
        "variants": [{
            "id": "sticky",
            "name": "Sticky",
            "blurb": "A tinted square you can fill.",
            "w": 244,
            "h": 244
        }, {
            "id": "lined",
            "name": "Lined",
            "blurb": "A wider sheet with a title.",
            "w": 308,
            "h": 228
        }],
        "options": [{
            "key": "tint",
            "label": "Tint",
            "type": "choice",
            "def": "neutral",
            "choices": [{
                "key": "neutral",
                "label": "Plain"
            }, {
                "key": "accent",
                "label": "Accent"
            }, {
                "key": "tertiary",
                "label": "Warm"
            }]
        }, {
            "key": "text",
            "label": "",
            "type": "hidden",
            "def": ""
        }]
    }, {
        "id": "todo",
        "name": "To-do",
        "blurb": "A short list you can tick off.",
        "variants": [{
            "id": "list",
            "name": "List",
            "blurb": "Everything, done items struck through.",
            "w": 284,
            "h": 288
        }, {
            "id": "focus",
            "name": "Focus",
            "blurb": "Only what is still outstanding.",
            "w": 268,
            "h": 200
        }],
        "options": [{
            "key": "hideDone",
            "label": "Hide finished items",
            "type": "bool",
            "def": false
        }, {
            "key": "items",
            "label": "",
            "type": "hidden",
            "def": "[]"
        }]
    }, {
        "id": "palette",
        "name": "Palette",
        "blurb": "The colours the shell is currently built from.",
        "variants": [{
            "id": "swatches",
            "name": "Roles",
            "blurb": "The key Material roles, click one to copy it.",
            "w": 288,
            "h": 172
        }, {
            "id": "ramp",
            "name": "Ramp",
            "blurb": "The accent walked down its tonal scale.",
            "w": 276,
            "h": 128
        }],
        "options": [{
            "key": "showHex",
            "label": "Show hex values",
            "type": "bool",
            "def": true
        }]
    }, {
        "id": "kdeconnect",
        "name": "Phone",
        "blurb": "Phone status, battery, signal and quick controls via KDE Connect.",
        "variants": [{
            "id": "card",
            "name": "Card",
            "blurb": "Battery, signal, and quick control buttons.",
            "w": 284,
            "h": 180
        }, {
            "id": "compact",
            "name": "Compact",
            "blurb": "Minimal row with phone battery & ring button.",
            "w": 220,
            "h": 96
        }, {
            "id": "remote",
            "name": "Remote",
            "blurb": "Battery, phone media controls, and quick actions.",
            "w": 300,
            "h": 220
        }],
        "options": [{
            "key": "showRing",
            "label": "Ring button",
            "type": "bool",
            "def": true
        }, {
            "key": "showClipboard",
            "label": "Clipboard button",
            "type": "bool",
            "def": true
        }, {
            "key": "showLock",
            "label": "Lock button",
            "type": "bool",
            "def": true
        }]
    }]

    function typeAt(typeId) {
        for (var i = 0; i < root.catalogue.length; i++) {
            if (root.catalogue[i].id === typeId)
                return root.catalogue[i];

        }
        return null;
    }

    function variantAt(typeId, variantId) {
        var t = root.typeAt(typeId);
        if (!t)
            return null;

        for (var i = 0; i < t.variants.length; i++) {
            if (t.variants[i].id === variantId)
                return t.variants[i];

        }
        return t.variants[0];
    }

    // a variant that carries its own size instead of taking the catalogue's
    function resizable(typeId, variantId) {
        var v = root.variantAt(typeId, variantId);
        return v !== null && v.resizable === true;
    }

    function sizeLimits(typeId, variantId) {
        var v = root.variantAt(typeId, variantId);
        return ({
            "minW": (v && v.minW) ? v.minW : 120,
            "minH": (v && v.minH) ? v.minH : 60,
            "maxW": (v && v.maxW) ? v.maxW : 5120,
            "maxH": (v && v.maxH) ? v.maxH : 2160
        });
    }

    // options the given variant actually honours
    function optionsFor(typeId, variantId) {
        var t = root.typeAt(typeId);
        if (!t)
            return [];

        return t.options.filter((o) => {
            return o.type !== "hidden" && (!o.variants || o.variants.indexOf(variantId) >= 0);
        });
    }

    function defaultOptions(typeId) {
        var t = root.typeAt(typeId);
        var out = {};
        if (!t)
            return out;

        for (var i = 0; i < t.options.length; i++) out[t.options[i].key] = t.options[i].def
        return out;
    }

    function indexOf(uid) {
        for (var i = 0; i < instances.count; i++) {
            if (instances.get(i).uid === uid)
                return i;

        }
        return -1;
    }

    function countOfType(typeId) {
        var n = 0;
        for (var i = 0; i < instances.count; i++) {
            if (instances.get(i).wtype === typeId)
                n++;

        }
        return n;
    }

    function countOfVariant(typeId, variantId) {
        var n = 0;
        for (var i = 0; i < instances.count; i++) {
            var e = instances.get(i);
            if (e.wtype === typeId && e.wvariant === variantId)
                n++;

        }
        return n;
    }

    // walks a coarse grid for the first slot that clears everything already placed
    function freeSpot(w, h) {
        var pad = 28;
        var step = 24;
        var top = root.spawnTop + pad;
        var maxX = Math.max(pad, root.canvasW - w - pad);
        var maxY = Math.max(top, root.canvasH - root.spawnBottom - h - pad);
        for (var y = top; y <= maxY; y += step) {
            for (var x = pad; x <= maxX; x += step) {
                var clear = true;
                for (var i = 0; i < instances.count && clear; i++) {
                    var e = instances.get(i);
                    if (x < e.wx + e.bw * e.zoom + 18 && x + w + 18 > e.wx && y < e.wy + e.bh * e.zoom + 18 && y + h + 18 > e.wy)
                        clear = false;

                }
                if (clear)
                    return ({
                        "x": x,
                        "y": y
                    });

            }
        }
        var n = instances.count;
        return ({
            "x": Math.min(maxX, pad + (n % 8) * 34),
            "y": Math.min(maxY, top + (n % 8) * 34)
        });
    }

    function spawn(typeId, variantId) {
        var v = root.variantAt(typeId, variantId);
        if (!v || root.full)
            return "";

        var spot = root.freeSpot(v.w, v.h);
        var uid = "w" + root.nextId;
        root.nextId += 1;
        root.topZ += 1;
        instances.append({
            "uid": uid,
            "wtype": typeId,
            "wvariant": v.id,
            "wx": spot.x,
            "wy": spot.y,
            "bw": v.w,
            "bh": v.h,
            "pinned": false,
            "zoom": 1,
            "zOrder": root.topZ,
            "screenName": "",
            "optsJson": JSON.stringify(root.defaultOptions(typeId)),
            "closing": false,
            "born": true
        });
        root.save();
        root.spawned(uid);
        return uid;
    }

    function close(uid) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "closing", true);
        purgeTimer.restart();
    }

    function purge() {
        for (var i = instances.count - 1; i >= 0; i--) {
            if (instances.get(i).closing)
                instances.remove(i);

        }
        root.save();
    }

    function closeAll() {
        for (var i = 0; i < instances.count; i++) instances.setProperty(i, "closing", true)
        purgeTimer.restart();
    }

    function closeType(typeId) {
        for (var i = 0; i < instances.count; i++) {
            if (instances.get(i).wtype === typeId)
                instances.setProperty(i, "closing", true);

        }
        purgeTimer.restart();
    }

    function setPos(uid, x, y) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "wx", Math.round(x));
        instances.setProperty(i, "wy", Math.round(y));
        root.save();
    }

    function setPinned(uid, v) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "pinned", v);
        root.save();
    }

    function togglePinned(uid) {
        var i = root.indexOf(uid);
        if (i >= 0)
            root.setPinned(uid, !instances.get(i).pinned);

    }

    function setVariant(uid, variantId) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        var e = instances.get(i);
        var v = root.variantAt(e.wtype, variantId);
        if (!v)
            return ;

        // a size you dragged survives a style swap, as long as the new style owns
        // its size too
        var keep = v.resizable === true && root.resizable(e.wtype, e.wvariant);
        var lim = root.sizeLimits(e.wtype, v.id);
        instances.setProperty(i, "wvariant", v.id);
        instances.setProperty(i, "bw", keep ? Math.max(lim.minW, Math.min(lim.maxW, e.bw)) : v.w);
        instances.setProperty(i, "bh", keep ? Math.max(lim.minH, Math.min(lim.maxH, e.bh)) : v.h);
        root.save();
    }

    function cycleVariant(uid) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        var e = instances.get(i);
        var t = root.typeAt(e.wtype);
        if (!t)
            return ;

        for (var k = 0; k < t.variants.length; k++) {
            if (t.variants[k].id === e.wvariant) {
                root.setVariant(uid, t.variants[(k + 1) % t.variants.length].id);
                return ;
            }
        }
    }

    function setSize(uid, w, h) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        var e = instances.get(i);
        var lim = root.sizeLimits(e.wtype, e.wvariant);
        instances.setProperty(i, "bw", Math.round(Math.max(lim.minW, Math.min(lim.maxW, w))));
        instances.setProperty(i, "bh", Math.round(Math.max(lim.minH, Math.min(lim.maxH, h))));
        root.save();
    }

    function resetSize(uid) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        var e = instances.get(i);
        var v = root.variantAt(e.wtype, e.wvariant);
        if (v)
            root.setSize(uid, v.w, v.h);

    }

    function setScale(uid, v) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "zoom", Math.max(0.75, Math.min(1.75, v)));
        root.save();
    }

    function setScreen(uid, name) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "screenName", name);
        root.save();
    }

    function setOption(uid, key, value) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        var opts = JSON.parse(instances.get(i).optsJson);
        if (opts[key] === value)
            return ;

        opts[key] = value;
        instances.setProperty(i, "optsJson", JSON.stringify(opts));
        root.save();
    }

    function raise(uid) {
        var i = root.indexOf(uid);
        if (i < 0 || instances.get(i).zOrder === root.topZ)
            return ;

        root.topZ += 1;
        instances.setProperty(i, "zOrder", root.topZ);
        root.save();
    }

    function readOption(optsJson, typeId, key) {
        var d = root.defaultOptions(typeId);
        try {
            var o = JSON.parse(optsJson);
            return o[key] !== undefined ? o[key] : d[key];
        } catch (e) {
            return d[key];
        }
    }

    // widgets used to live on a layer the bar had already pushed down, so every
    // coordinate in an older file is short by the strip it reserved. the shift is
    // read off Prefs, so this has to wait for it: before that the answer would be
    // whatever the JsonAdapter defaults say rather than what the bar is doing
    function liftOntoFullBoard() {
        if (!root.needsLift || !Prefs.loaded)
            return ;

        root.needsLift = false;
        var dy = root.spawnTop;
        if (dy > 0) {
            for (var i = 0; i < instances.count; i++) instances.setProperty(i, "wy", instances.get(i).wy + dy)
        }
        root.save();
    }

    function save() {
        saveDebounce.restart();
    }

    function serialise() {
        var out = [];
        for (var i = 0; i < instances.count; i++) {
            var e = instances.get(i);
            if (e.closing)
                continue;

            out.push({
                "uid": e.uid,
                "type": e.wtype,
                "variant": e.wvariant,
                "wx": e.wx,
                "wy": e.wy,
                "bw": e.bw,
                "bh": e.bh,
                "pinned": e.pinned,
                "zoom": e.zoom,
                "zOrder": e.zOrder,
                "screenName": e.screenName,
                "opts": JSON.parse(e.optsJson)
            });
        }
        return JSON.stringify({
            "nextId": root.nextId,
            "boardFull": true,
            "instances": out
        }, null, 2);
    }

    function restore(raw) {
        var data = null;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            data = null;
        }
        instances.clear();
        if (!data || !data.instances) {
            root.loaded = true;
            return ;
        }
        for (var i = 0; i < data.instances.length; i++) {
            var e = data.instances[i];
            var v = root.variantAt(e.type, e.variant);
            if (!v)
                continue;

            var opts = root.defaultOptions(e.type);
            for (var k in (e.opts || {})) opts[k] = e.opts[k]
            root.topZ = Math.max(root.topZ, e.zOrder || 1);
            instances.append({
                "uid": e.uid,
                "wtype": e.type,
                "wvariant": v.id,
                "wx": e.wx || 40,
                "wy": e.wy || 40,
                "bw": (v.resizable === true && e.bw) ? e.bw : v.w,
                "bh": (v.resizable === true && e.bh) ? e.bh : v.h,
                "pinned": e.pinned === true,
                "zoom": e.zoom || 1,
                "zOrder": e.zOrder || 1,
                "screenName": e.screenName || "",
                "optsJson": JSON.stringify(opts),
                "closing": false,
                "born": false
            });
        }
        root.nextId = Math.max(data.nextId || 1, instances.count + 1);
        root.needsLift = data.boardFull !== true;
        root.loaded = true;
        root.liftOntoFullBoard();
    }

    Connections {
        function onLoadedChanged() {
            root.liftOntoFullBoard();
        }

        target: Prefs
    }

    ListModel {
        id: instances
    }

    // long enough that the card has finished fading out before it is destroyed,
    // at whatever animation speed the user has chosen
    Timer {
        id: purgeTimer

        interval: Math.max(60, Math.round(340 * Theme.motionScale))
        onTriggered: root.purge()
    }

    Timer {
        id: saveDebounce

        interval: 220
        onTriggered: {
            if (root.loaded)
                stateFile.setText(root.serialise());

        }
    }

    FileView {
        id: stateFile

        path: root.home + "/.config/quickshell/lucidwidgets/widgets.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            if (!root.loaded)
                root.restore(text());

        }
        onLoadFailed: root.loaded = true
    }

}
