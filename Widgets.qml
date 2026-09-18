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
    // the preset on the desktop right now, "" once the arrangement is your own
    property string presetId: ""
    // presets saved from your own desktop, in the same shape as the built-in ones
    property var userPresets: []
    // the unsaved arrangement a preset last replaced, so it is one click away
    property var lastLayout: []
    // cards a preset took off while they still held something you wrote
    property var stash: []
    // the primary screen's cards as plain entries, for drawing it small
    property var desktopLayout: []
    // the last layout only has somewhere to go back to while something else is showing
    readonly property bool canRestore: root.lastLayout.length > 0 && (root.presetId !== "" || instances.count === 0)

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
            "w": 268,
            "h": 180
        }, {
            "id": "compact",
            "name": "Compact",
            "blurb": "Minimal row with phone battery & ring button.",
            "w": 216,
            "h": 96
        }, {
            "id": "remote",
            "name": "Remote",
            "blurb": "Battery, phone media controls, and quick actions.",
            "w": 284,
            "h": 220
        }],
        "options": [{
            "key": "showShare",
            "label": "Send file button",
            "type": "bool",
            "def": true
        }, {
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
            "key": "showBrowse",
            "label": "Browse files button",
            "type": "bool",
            "def": true,
            "variants": ["card", "remote"]
        }, {
            "key": "deviceId",
            "label": "",
            "type": "hidden",
            "def": ""
        }]
    }]

    // the full-width bars every preset stands on. listed first in each, so the cards
    // after them sit on top wherever a peak reaches up behind one
    readonly property var footBars: ({ "type": "visualiser", "variant": "bars", "at": "bl", "x": 0, "y": 940, "w": 1920, "h": 140, "stretch": true, "pinned": true, "opts": { "density": "fine" } })

    // laid out on a 1920x1080 screen. "at" pins a card to an edge, t/m/b then l/c/r,
    // so a cluster holds together at any other size; "stretch" pins both sides.
    // cards stop at y 924, clear of the bars
    readonly property var presets: [{
        "id": "collage",
        "name": "Collage",
        "blurb": "Notes, cover art, the time and your charge, stacked on the right.",
        "cards": [
            root.footBars,
            { "type": "notes", "variant": "sticky", "at": "tr", "x": 1646, "y": 112 },
            { "type": "media", "variant": "art", "at": "tr", "x": 1386, "y": 185 },
            { "type": "battery", "variant": "ring", "at": "tr", "x": 1658, "y": 372, "zoom": 1.25 },
            { "type": "clock", "variant": "stack", "at": "tr", "x": 1410, "y": 445 }
        ]
    }, {
        "id": "bookends",
        "name": "Bookends",
        "blurb": "Date and weather on the left, the time and your music on the right.",
        "cards": [
            root.footBars,
            { "type": "calendar", "variant": "month", "at": "tl", "x": 20, "y": 110 },
            { "type": "weather", "variant": "compact", "at": "tl", "x": 26, "y": 432, "zoom": 1.5 },
            { "type": "clock", "variant": "stack", "at": "tr", "x": 1612, "y": 178, "zoom": 1.25 },
            { "type": "media", "variant": "card", "at": "tr", "x": 1612, "y": 489 }
        ]
    }, {
        "id": "dashboard",
        "name": "Dashboard",
        "blurb": "The day down the left, the machine and your list down the right.",
        "cards": [
            root.footBars,
            { "type": "clock", "variant": "stack", "at": "tl", "x": 46, "y": 287, "zoom": 1.25 },
            { "type": "media", "variant": "card", "at": "tl", "x": 349, "y": 283 },
            { "type": "calendar", "variant": "month", "at": "tl", "x": 33, "y": 618 },
            { "type": "weather", "variant": "compact", "at": "tl", "x": 349, "y": 734, "zoom": 1.5 },
            { "type": "battery", "variant": "bar", "at": "tr", "x": 1622, "y": 126 },
            { "type": "system", "variant": "rings", "at": "tr", "x": 1578, "y": 260 },
            { "type": "system", "variant": "graph", "at": "tr", "x": 1562, "y": 434 },
            { "type": "todo", "variant": "list", "at": "tr", "x": 1586, "y": 636 }
        ]
    }, {
        "id": "minimal",
        "name": "Minimal",
        "blurb": "Just the time on the wallpaper, and the music along the bottom.",
        "cards": [
            root.footBars,
            { "type": "clock", "variant": "minimal", "at": "bl", "x": 56, "y": 756, "zoom": 1.75 }
        ]
    }, {
        "id": "focus",
        "name": "Focus",
        "blurb": "The time and what is left to do, front and centre.",
        "cards": [
            root.footBars,
            { "type": "clock", "variant": "analog", "at": "tc", "x": 652, "y": 120, "zoom": 1.25 },
            { "type": "todo", "variant": "focus", "at": "tc", "x": 933, "y": 120, "zoom": 1.25 }
        ]
    }, {
        "id": "planner",
        "name": "Planner",
        "blurb": "The hour, the month, a list and a notepad, in reading order.",
        "cards": [
            root.footBars,
            { "type": "clock", "variant": "digital", "at": "tl", "x": 40, "y": 100 },
            { "type": "todo", "variant": "list", "at": "tl", "x": 356, "y": 100 },
            { "type": "calendar", "variant": "month", "at": "tl", "x": 40, "y": 264 },
            { "type": "notes", "variant": "lined", "at": "tl", "x": 356, "y": 404 }
        ]
    }, {
        "id": "studio",
        "name": "Studio",
        "blurb": "Big cover art, and the sound as one flowing wave beside it.",
        "cards": [
            { "type": "visualiser", "variant": "wave", "at": "bl", "x": 422, "y": 930, "w": 1498, "h": 150, "stretch": true, "pinned": true, "opts": { "tint": "gradient" } },
            { "type": "media", "variant": "art", "at": "bl", "x": 40, "y": 674, "zoom": 1.5 }
        ]
    }, {
        "id": "moodboard",
        "name": "Moodboard",
        "blurb": "Your palette beside the cover art, and a note for ideas.",
        "cards": [
            root.footBars,
            { "type": "media", "variant": "art", "at": "tl", "x": 40, "y": 100 },
            { "type": "palette", "variant": "swatches", "at": "tl", "x": 300, "y": 100 },
            { "type": "palette", "variant": "ramp", "at": "tl", "x": 300, "y": 288 },
            { "type": "notes", "variant": "sticky", "at": "tl", "x": 40, "y": 360, "opts": { "tint": "tertiary" } }
        ]
    }, {
        "id": "traveller",
        "name": "Traveller",
        "blurb": "Three cities, the forecast and the week ahead.",
        "cards": [
            root.footBars,
            { "type": "clock", "variant": "world", "at": "tr", "x": 964, "y": 100 },
            { "type": "weather", "variant": "forecast", "at": "tr", "x": 1244, "y": 100 },
            { "type": "calendar", "variant": "week", "at": "tr", "x": 1580, "y": 100 }
        ]
    }, {
        "id": "monitor",
        "name": "Monitor",
        "blurb": "Load, memory, disk and charge, tucked into a corner.",
        "cards": [
            root.footBars,
            { "type": "system", "variant": "rings", "at": "br", "x": 1284, "y": 556 },
            { "type": "battery", "variant": "detail", "at": "br", "x": 1632, "y": 558 },
            { "type": "system", "variant": "bars", "at": "br", "x": 1308, "y": 730 },
            { "type": "system", "variant": "graph", "at": "br", "x": 1592, "y": 738 }
        ]
    }, {
        "id": "corners",
        "name": "Corners",
        "blurb": "One card in each corner and nothing in the middle.",
        "cards": [
            root.footBars,
            { "type": "clock", "variant": "digital", "at": "tl", "x": 40, "y": 100 },
            { "type": "weather", "variant": "current", "at": "tr", "x": 1616, "y": 100 },
            { "type": "media", "variant": "row", "at": "bl", "x": 40, "y": 806 },
            { "type": "battery", "variant": "bar", "at": "br", "x": 1632, "y": 806 }
        ]
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
        root.edited();
        root.save();
        root.spawned(uid);
        return uid;
    }

    function close(uid) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "closing", true);
        root.edited();
        purgeTimer.restart();
    }

    function purge() {
        for (var i = instances.count - 1; i >= 0; i--) {
            if (instances.get(i).closing)
                instances.remove(i);

        }
        root.touched();
        root.save();
    }

    // an unsaved layout is set aside before it is cleared away, so it can come back
    function closeAll() {
        if (root.presetId === "" && root.liveCount() > 0)
            root.lastLayout = root.snapshot(true);

        for (var i = 0; i < instances.count; i++) instances.setProperty(i, "closing", true)
        root.edited();
        purgeTimer.restart();
    }

    function closeType(typeId) {
        for (var i = 0; i < instances.count; i++) {
            if (instances.get(i).wtype === typeId)
                instances.setProperty(i, "closing", true);

        }
        root.edited();
        purgeTimer.restart();
    }

    // a press without travel still lands here, so only a real move counts as an edit
    function setPos(uid, x, y) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        var e = instances.get(i);
        if (e.wx === Math.round(x) && e.wy === Math.round(y))
            return ;

        instances.setProperty(i, "wx", Math.round(x));
        instances.setProperty(i, "wy", Math.round(y));
        root.edited();
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
        root.edited();
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
        var nw = Math.round(Math.max(lim.minW, Math.min(lim.maxW, w)));
        var nh = Math.round(Math.max(lim.minH, Math.min(lim.maxH, h)));
        if (e.bw === nw && e.bh === nh)
            return ;

        instances.setProperty(i, "bw", nw);
        instances.setProperty(i, "bh", nh);
        root.edited();
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
        root.edited();
        root.save();
    }

    function setScreen(uid, name) {
        var i = root.indexOf(uid);
        if (i < 0)
            return ;

        instances.setProperty(i, "screenName", name);
        root.edited();
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

    // anything done by hand to what is placed or where
    function edited() {
        root.presetId = "";
        root.touched();
    }

    function touched() {
        Qt.callLater(root.refreshDesktop);
    }

    function refreshDesktop() {
        var next = root.snapshot(true);
        if (JSON.stringify(next) !== JSON.stringify(root.desktopLayout))
            root.desktopLayout = next;

    }

    // the main display is wherever the shell sits, the first one otherwise
    function primaryScreen() {
        return Monitors.mainScreen;
    }

    // presets only ever arrange the primary screen; cards on the others are left alone
    function onPrimary(e) {
        var scr = root.primaryScreen();
        return e.screenName === "" || (scr !== null && e.screenName === scr.name);
    }

    function liveCount() {
        var n = 0;
        for (var i = 0; i < instances.count; i++) {
            var e = instances.get(i);
            if (!e.closing && root.onPrimary(e))
                n++;

        }
        return n;
    }

    // one card in the shape widgets.json, a layout and the stash all share
    function entryOf(e) {
        return ({
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

    function snapshot(primaryOnly) {
        var out = [];
        for (var i = 0; i < instances.count; i++) {
            var e = instances.get(i);
            if (!e.closing && (primaryOnly !== true || root.onPrimary(e)))
                out.push(root.entryOf(e));

        }
        return out;
    }

    // built-ins first, so a built-in tile never re-reads when a saved preset changes
    function presetAt(id) {
        for (var i = 0; i < root.presets.length; i++) {
            if (root.presets[i].id === id)
                return root.presets[i];

        }
        for (var j = 0; j < root.userPresets.length; j++) {
            if (root.userPresets[j].id === id)
                return root.userPresets[j];

        }
        return null;
    }

    function userPresetNamed(name) {
        var key = String(name).trim().toLowerCase();
        for (var i = 0; i < root.userPresets.length; i++) {
            if (String(root.userPresets[i].name).toLowerCase() === key)
                return root.userPresets[i];

        }
        return null;
    }

    function presetLayout(id) {
        return root.layoutOf(root.presetAt(id));
    }

    // a preset's cards placed on the primary screen. a preset remembers the screen it
    // was laid out on, and the whole arrangement scales from that one to this one
    function layoutOf(p) {
        if (!p || !Array.isArray(p.cards))
            return [];

        var scr = root.primaryScreen();
        var W = scr ? scr.width : root.canvasW;
        var H = scr ? scr.height : root.canvasH;
        var RW = p.refW || 1920;
        var RH = p.refH || 1080;
        var s = Math.max(0.6, Math.min(1.6, Math.min(W / RW, H / RH)));
        var out = [];
        for (var i = 0; i < p.cards.length; i++) {
            var c = p.cards[i];
            var v = root.variantAt(c.type, c.variant);
            if (!v)
                continue;

            var z0 = c.zoom || 1;
            var zoom = Math.round(z0 * s * 100) / 100;
            var bw = (v.resizable === true && c.w) ? c.w : v.w;
            var bh = (v.resizable === true && c.h) ? c.h : v.h;
            var refW = bw * z0;
            var refH = bh * z0;
            var at = c.at || "tl";
            var x = c.x * s;
            if (c.stretch === true)
                bw = (W - (RW - c.x - refW) * s - x) / zoom;
            else if (at.charAt(1) === "r")
                x = W - (RW - c.x - refW) * s - bw * zoom;
            else if (at.charAt(1) === "c")
                x = W / 2 + (c.x + refW / 2 - RW / 2) * s - bw * zoom / 2;
            var y = c.y * s;
            if (at.charAt(0) === "b")
                y = H - (RH - c.y - refH) * s - bh * zoom;
            else if (at.charAt(0) === "m")
                y = H / 2 + (c.y + refH / 2 - RH / 2) * s - bh * zoom / 2;
            if (v.resizable === true) {
                var lim = root.sizeLimits(c.type, v.id);
                bw = Math.max(lim.minW, Math.min(lim.maxW, bw));
                bh = Math.max(lim.minH, Math.min(lim.maxH, bh));
            }
            var entry = {
                "type": c.type,
                "variant": v.id,
                "wx": Math.round(Math.max(0, Math.min(W - bw * zoom, x))),
                "wy": Math.round(Math.max(0, Math.min(H - bh * zoom, y))),
                "bw": Math.round(bw),
                "bh": Math.round(bh),
                "zoom": zoom,
                "pinned": c.pinned === true,
                "screenName": "",
                "opts": c.opts || ({})
            };
            // a saved preset knows which cards it was made from
            if (c.uid !== undefined)
                entry.uid = c.uid;

            out.push(entry);
        }
        return out;
    }

    // the desktop written down as a preset: each cluster pinned to the edge it sits
    // nearest, so the arrangement still hugs its corners on a screen of another size
    function presetFromDesktop(id, name) {
        var scr = root.primaryScreen();
        var W = scr ? scr.width : root.canvasW;
        var H = scr ? scr.height : root.canvasH;
        var cards = root.snapshot(true);
        var box = cards.map((c) => {
            var w = c.bw * c.zoom;
            var h = c.bh * c.zoom;
            return ({
                "x": Math.max(0, Math.min(W - w, c.wx)),
                "y": Math.max(0, Math.min(H - h, c.wy)),
                "w": w,
                "h": h
            });
        });
        // a resizable card run out to a screen edge keeps both of its sides pinned
        var stretch = cards.map((c, i) => {
            return root.resizable(c.type, c.variant) && box[i].w >= W / 2 && (box[i].x <= 4 || box[i].x + box[i].w >= W - 4);
        });
        // cards within a hand's width of each other move as one
        var group = cards.map((c, i) => {
            return i;
        });
        var find = (i) => {
            while (group[i] !== i)
                i = group[i];
            return i;
        };
        var near = 48;
        for (var i = 0; i < cards.length; i++) {
            for (var j = i + 1; j < cards.length; j++) {
                var a = box[i];
                var b = box[j];
                if (!stretch[i] && !stretch[j] && a.x - near < b.x + b.w && b.x - near < a.x + a.w && a.y - near < b.y + b.h && b.y - near < a.y + a.h)
                    group[find(i)] = find(j);

            }
        }
        var ext = {};
        for (var k = 0; k < cards.length; k++) {
            var g = find(k);
            var r = ext[g] || ({
                "x0": W,
                "y0": H,
                "x1": 0,
                "y1": 0
            });
            r.x0 = Math.min(r.x0, box[k].x);
            r.y0 = Math.min(r.y0, box[k].y);
            r.x1 = Math.max(r.x1, box[k].x + box[k].w);
            r.y1 = Math.max(r.y1, box[k].y + box[k].h);
            ext[g] = r;
        }
        var out = [];
        for (var n = 0; n < cards.length; n++) {
            var c = cards[n];
            var e = ext[find(n)];
            var cx = (e.x0 + e.x1) / 2;
            var cy = (e.y0 + e.y1) / 2;
            out.push({
                "uid": c.uid,
                "type": c.type,
                "variant": c.variant,
                "at": (cy < H / 3 ? "t" : (cy > H * 2 / 3 ? "b" : "m")) + (cx < W / 3 ? "l" : (cx > W * 2 / 3 ? "r" : "c")),
                "x": Math.round(box[n].x),
                "y": Math.round(box[n].y),
                "w": c.bw,
                "h": c.bh,
                "zoom": c.zoom,
                "stretch": stretch[n],
                "pinned": c.pinned === true,
                "opts": c.opts
            });
        }
        return ({
            "id": id,
            "name": name,
            "refW": W,
            "refH": H,
            "saved": Date.now(),
            "cards": out
        });
    }

    // keeps the primary screen as a preset of your own; a name already in use is
    // updated where it stands rather than doubled
    function savePreset(name) {
        var clean = String(name).trim().substring(0, 32);
        if (clean === "" || root.liveCount() === 0)
            return "";

        var old = root.userPresetNamed(clean);
        var id = old !== null ? old.id : "user-" + Date.now().toString(36);
        var p = root.presetFromDesktop(id, old !== null ? old.name : clean);
        var list = root.userPresets.slice();
        var at = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === id)
                at = i;

        }
        if (at >= 0)
            list[at] = p;
        else
            list.unshift(p);
        root.userPresets = list;
        root.presetId = id;
        root.save();
        return id;
    }

    // the widgets on the desktop stay where they are; only the preset goes
    function deletePreset(id) {
        var list = root.userPresets.filter((q) => {
            return q.id !== id;
        });
        if (list.length === root.userPresets.length)
            return false;

        root.userPresets = list;
        if (root.presetId === id)
            root.presetId = "";

        root.save();
        return true;
    }

    // the options nobody picks from a menu: the text of a note, the items of a list
    function isContentKey(typeId, key) {
        var t = root.typeAt(typeId);
        if (!t)
            return false;

        for (var i = 0; i < t.options.length; i++) {
            if (t.options[i].key === key)
                return t.options[i].type === "hidden";

        }
        return false;
    }

    function holdsContent(typeId, opts) {
        var d = root.defaultOptions(typeId);
        for (var k in opts) {
            if (root.isContentKey(typeId, k) && opts[k] !== undefined && opts[k] !== d[k])
                return true;

        }
        return false;
    }

    // incoming options win, except anything you wrote, which stays with its card
    function mergeOpts(typeId, current, incoming) {
        var d = root.defaultOptions(typeId);
        var out = {};
        for (var k in d) out[k] = d[k]
        for (var k1 in current) out[k1] = current[k1]
        for (var k2 in incoming) {
            if (root.isContentKey(typeId, k2) && out[k2] !== undefined && out[k2] !== d[k2])
                continue;

            out[k2] = incoming[k2];
        }
        return out;
    }

    // moves what is already out onto a new layout instead of rebuilding it, so a card
    // that stays slides to its new spot and keeps whatever you wrote in it
    function arrange(plan) {
        root.menuUid = "";
        root.editUid = "";
        var live = [];
        for (var i = 0; i < instances.count; i++) {
            var r = instances.get(i);
            if (!r.closing && root.onPrimary(r))
                live.push({
                "uid": r.uid,
                "wtype": r.wtype,
                "wvariant": r.wvariant,
                "wx": r.wx,
                "wy": r.wy
            });

        }
        // reading order, so the upper of two alike cards takes the upper slot
        live.sort((a, b) => {
            return a.wy !== b.wy ? a.wy - b.wy : a.wx - b.wx;
        });
        var stash = root.stash.slice();
        var taken = {};
        var pick = plan.map(() => {
            return null;
        });
        var fromLive = (e, test) => {
            for (var j = 0; j < live.length; j++) {
                if (!taken[live[j].uid] && test(e, live[j])) {
                    taken[live[j].uid] = true;
                    return ({
                        "live": true,
                        "uid": live[j].uid
                    });
                }
            }
            return null;
        };
        var fromStash = (e, test) => {
            for (var j = 0; j < stash.length; j++) {
                if (test(e, stash[j]))
                    return ({
                    "live": false,
                    "entry": stash.splice(j, 1)[0]
                });

            }
            return null;
        };
        // the same card, then one parked earlier, then the same look, then the same kind
        var passes = [(e) => {
            return fromLive(e, (a, m) => {
                return a.uid !== undefined && a.uid === m.uid;
            });
        }, (e) => {
            return fromStash(e, (a, s) => {
                return a.uid !== undefined && a.uid === s.uid;
            });
        }, (e) => {
            return fromLive(e, (a, m) => {
                return a.type === m.wtype && a.variant === m.wvariant;
            });
        }, (e) => {
            return fromLive(e, (a, m) => {
                return a.type === m.wtype;
            });
        }, (e) => {
            return fromStash(e, (a, s) => {
                return a.type === s.type;
            });
        }];
        for (var q = 0; q < passes.length; q++) {
            for (var p = 0; p < plan.length; p++) {
                if (pick[p] === null)
                    pick[p] = passes[q](plan[p]);

            }
        }
        for (var n = 0; n < plan.length; n++) {
            var e = plan[n];
            var v = root.variantAt(e.type, e.variant);
            if (!v)
                continue;

            var got = pick[n];
            var place = {
                "wvariant": v.id,
                "wx": e.wx,
                "wy": e.wy,
                "bw": v.resizable === true ? e.bw : v.w,
                "bh": v.resizable === true ? e.bh : v.h,
                "pinned": e.pinned === true,
                "zoom": e.zoom || 1,
                "zOrder": ++root.topZ,
                "screenName": e.screenName || ""
            };
            if (got !== null && got.live) {
                var k = root.indexOf(got.uid);
                place.optsJson = JSON.stringify(root.mergeOpts(e.type, JSON.parse(instances.get(k).optsJson), e.opts || {}));
                instances.set(k, place);
                continue;
            }
            var base = got !== null ? got.entry : null;
            var uid = base !== null ? base.uid : (e.uid !== undefined ? e.uid : "w" + root.nextId++);
            place.optsJson = JSON.stringify(root.mergeOpts(e.type, base !== null ? (base.opts || {}) : {}, e.opts || {}));
            place.closing = false;
            place.born = true;
            // a card still fading out from a moment ago turns round instead of doubling up
            var fading = root.indexOf(uid);
            taken[uid] = true;
            if (fading >= 0) {
                instances.set(fading, place);
            } else {
                place.uid = uid;
                place.wtype = e.type;
                instances.append(place);
            }
        }
        for (var g = 0; g < live.length; g++) {
            if (taken[live[g].uid])
                continue;

            var at = root.indexOf(live[g].uid);
            var gone = instances.get(at);
            if (root.holdsContent(gone.wtype, JSON.parse(gone.optsJson)))
                stash.push(root.entryOf(gone));

            instances.setProperty(at, "closing", true);
        }
        root.stash = stash.slice(-12);
        purgeTimer.restart();
        root.touched();
        root.save();
    }

    function applyPreset(id) {
        var plan = root.presetLayout(id);
        if (plan.length === 0)
            return false;

        // an arrangement nobody saved is set aside first, so a preset never costs you one
        if (root.presetId === "" && root.liveCount() > 0)
            root.lastLayout = root.snapshot(true);

        root.arrange(plan);
        root.presetId = id;
        return true;
    }

    function restoreLast() {
        if (!root.canRestore)
            return false;

        root.arrange(root.lastLayout);
        root.presetId = "";
        return true;
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
        root.touched();
        root.save();
    }

    function save() {
        saveDebounce.restart();
    }

    function serialise() {
        return JSON.stringify({
            "nextId": root.nextId,
            "boardFull": true,
            "preset": root.presetId,
            "saved": root.userPresets,
            "last": root.lastLayout,
            "stash": root.stash,
            "instances": root.snapshot(false)
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
                "wx": typeof e.wx === "number" ? e.wx : 40,
                "wy": typeof e.wy === "number" ? e.wy : 40,
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
        root.userPresets = Array.isArray(data.saved) ? data.saved.filter((p) => {
            return p && typeof p.id === "string" && typeof p.name === "string" && Array.isArray(p.cards);
        }) : [];
        root.presetId = (typeof data.preset === "string" && root.presetAt(data.preset) !== null) ? data.preset : "";
        root.lastLayout = Array.isArray(data.last) ? data.last : [];
        root.stash = Array.isArray(data.stash) ? data.stash : [];
        root.needsLift = data.boardFull !== true;
        root.loaded = true;
        root.refreshDesktop();
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
