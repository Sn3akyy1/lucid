// the lock screen's layouts and widgets, shared by the lock, the login screen
// and the settings that edit them. a layout is plain data — a preset, which
// widget sits in which of its slots, and each widget's options — so the login
// screen can wear one written by any account without running its code.
// not a .pragma library: a hot reload would otherwise keep the old copy

// marks the words the settings show, so support/i18n-check.py keeps them in
// the catalogues. the shell translates them where it shows them (LockStyle,
// and the parts through lock.tr); the login screen has no catalogues
var I18n = {
    "tr": function(text) {
        return text;
    }
};

var defaultPreset = "centre";

// slots are listed in reading order. `row` lays its widgets side by side
var presets = [
    {
        "id": "centre",
        "kind": I18n.tr("Clock"),
        "name": I18n.tr("Centre"),
        "blurb": I18n.tr("A big clock in the middle, with the sign-in under it"),
        "slots": [
            { "id": "topLeft", "name": I18n.tr("Top left"), "align": "left" },
            { "id": "topRight", "name": I18n.tr("Top right"), "align": "right" },
            { "id": "hero", "name": I18n.tr("Centre"), "align": "center" },
            { "id": "below", "name": I18n.tr("Under the clock"), "align": "center" },
            { "id": "bottomLeft", "name": I18n.tr("Bottom left"), "align": "left" },
            { "id": "bottomRight", "name": I18n.tr("Bottom right"), "align": "right" }
        ],
        "defaults": {
            "topLeft": ["weather"],
            "topRight": ["status"],
            "hero": ["clock", "date"],
            "below": ["media", "notifications"],
            "bottomLeft": ["power"]
        },
        "opts": {
            "clock": { "style": "stacked", "size": "XL" },
            "date": { "size": "L" },
            "notifications": { "style": "icons" }
        }
    },
    {
        "id": "split",
        "kind": I18n.tr("Classic"),
        "name": I18n.tr("Split"),
        "blurb": I18n.tr("The day on the left, the sign-in and what is happening on the right"),
        "slots": [
            { "id": "topLeft", "name": I18n.tr("Top left"), "align": "left" },
            { "id": "topRight", "name": I18n.tr("Top right"), "align": "right" },
            { "id": "hero", "name": I18n.tr("Left"), "align": "left" },
            { "id": "side", "name": I18n.tr("Under the sign-in"), "align": "left" },
            { "id": "bottomLeft", "name": I18n.tr("Bottom left"), "align": "left" }
        ],
        "defaults": {
            "topLeft": ["weather"],
            "topRight": ["status"],
            "hero": ["clock", "date", "greeting"],
            "side": ["media", "notifications"],
            "bottomLeft": ["power"]
        },
        "opts": {
            "clock": { "style": "stacked", "size": "L" }
        }
    },
    {
        "id": "panel",
        "kind": I18n.tr("Sheet"),
        "name": I18n.tr("Panel"),
        "blurb": I18n.tr("A side sheet holds the sign-in; the wallpaper keeps the rest"),
        "slots": [
            { "id": "canvasTop", "name": I18n.tr("Top corner"), "align": "left" },
            { "id": "canvas", "name": I18n.tr("Wallpaper"), "align": "left" },
            { "id": "sheetTop", "name": I18n.tr("Sheet, top"), "align": "center" },
            { "id": "sheetBottom", "name": I18n.tr("Sheet, bottom"), "align": "center" }
        ],
        "defaults": {
            "canvasTop": ["weather"],
            "canvas": ["clock", "date"],
            "sheetTop": ["status"],
            "sheetBottom": ["media", "notifications", "power"]
        },
        "opts": {
            "clock": { "style": "stacked", "size": "XL" },
            "power": { "style": "round" },
            "notifications": { "style": "list" }
        },
        "options": [
            { "key": "side", "name": I18n.tr("Sheet on the"), "type": "choice", "def": "right", "choices": [["left", I18n.tr("Left")], ["right", I18n.tr("Right")]] }
        ]
    },
    {
        "id": "minimal",
        "kind": I18n.tr("Quiet"),
        "name": I18n.tr("Minimal"),
        "blurb": I18n.tr("Only the time, until you start typing"),
        "slots": [
            { "id": "hero", "name": I18n.tr("Centre"), "align": "center" },
            { "id": "foot", "name": I18n.tr("Bottom"), "align": "center", "row": true }
        ],
        "defaults": {
            "hero": ["clock", "date"],
            "foot": ["status", "power"]
        },
        "opts": {
            "clock": { "style": "inline", "size": "XL" },
            "status": { "style": "icons" },
            "power": { "style": "round" }
        }
    },
    {
        "id": "bento",
        "kind": I18n.tr("Cards"),
        "name": I18n.tr("Bento"),
        "blurb": I18n.tr("Every widget on a card of its own, gathered in the middle"),
        "slots": [
            { "id": "top", "name": I18n.tr("Top"), "align": "center", "row": true },
            { "id": "left", "name": I18n.tr("Left cards"), "align": "center", "cards": true },
            { "id": "right", "name": I18n.tr("Right cards"), "align": "center", "cards": true },
            { "id": "foot", "name": I18n.tr("Bottom"), "align": "center", "row": true }
        ],
        "defaults": {
            "top": ["status"],
            "left": ["clock", "weather", "agenda"],
            "right": ["media", "notifications"],
            "foot": ["power"]
        },
        "opts": {
            "clock": { "style": "shapes", "size": "L" },
            "weather": { "style": "card" },
            "power": { "style": "round" }
        }
    },
    {
        "id": "deck",
        "kind": I18n.tr("Music"),
        "name": I18n.tr("Deck"),
        "blurb": I18n.tr("Whatever is playing, up big, with the time beside it. With nothing playing the time takes the middle"),
        "slots": [
            { "id": "deck", "name": I18n.tr("Left"), "align": "left" },
            { "id": "hero", "name": I18n.tr("Right"), "align": "center" },
            { "id": "foot", "name": I18n.tr("Bottom left"), "align": "left", "row": true },
            { "id": "corner", "name": I18n.tr("Beside the sign-in"), "align": "right", "row": true }
        ],
        "defaults": {
            "deck": ["media"],
            "hero": ["clock", "date"],
            "foot": ["weather", "status", "notifications"],
            "corner": ["power"]
        },
        "opts": {
            "media": { "style": "deck" },
            "clock": { "style": "stacked", "size": "XL" },
            "date": { "size": "L" },
            "weather": { "style": "compact" },
            "status": { "style": "icons" },
            "notifications": { "style": "count" },
            "power": { "style": "round" }
        }
    }
];

var sizes = [["S", I18n.tr("Small")], ["M", I18n.tr("Medium")], ["L", I18n.tr("Large")], ["XL", I18n.tr("Extra large")]];

// where: both | lock (needs a session, so never on the login screen)
var widgets = [
    {
        "id": "clock",
        "name": I18n.tr("Clock"),
        "icon": "schedule",
        "where": "both",
        "blurb": I18n.tr("The time, as big as you like"),
        "styles": [["stacked", I18n.tr("Stacked")], ["inline", I18n.tr("Inline")], ["dial", I18n.tr("Dial")], ["shapes", I18n.tr("Shapes")]],
        "sized": true,
        "def": { "style": "stacked", "size": "L" },
        "options": [
            { "key": "tone", "name": I18n.tr("Colour"), "type": "choice", "def": "accent", "choices": [["accent", I18n.tr("Two-tone")], ["mono", I18n.tr("Plain")]] },
            { "key": "seconds", "name": I18n.tr("Seconds"), "type": "bool", "def": false, "styles": ["inline", "dial"] }
        ]
    },
    {
        "id": "date",
        "name": I18n.tr("Date"),
        "icon": "event",
        "where": "both",
        "blurb": I18n.tr("Today's date"),
        "styles": [["long", I18n.tr("Long")], ["short", I18n.tr("Short")], ["stacked", I18n.tr("Stacked")]],
        "sized": true,
        "def": { "style": "long", "size": "M" }
    },
    {
        "id": "greeting",
        "name": I18n.tr("Greeting"),
        "icon": "person",
        "where": "both",
        "blurb": I18n.tr("Good morning, by name"),
        "styles": [["name", I18n.tr("With your name")], ["plain", I18n.tr("Just the greeting")]],
        "sized": true,
        "def": { "style": "name", "size": "M" }
    },
    {
        "id": "weather",
        "name": I18n.tr("Weather"),
        "icon": "partly_cloudy_day",
        "where": "both",
        "blurb": I18n.tr("The sky outside. The login screen shows the last reading, if you allow it"),
        "styles": [["line", I18n.tr("Line")], ["compact", I18n.tr("Compact")], ["card", I18n.tr("Card")]],
        "sized": true,
        "def": { "style": "line", "size": "M" },
        "options": [
            { "key": "details", "name": I18n.tr("High, low and feels like"), "type": "bool", "def": true, "styles": ["line", "card"] }
        ]
    },
    {
        "id": "status",
        "name": I18n.tr("Status"),
        "icon": "battery_full",
        "where": "both",
        "blurb": I18n.tr("Battery, network, Bluetooth and the keyboard layout"),
        "styles": [["chips", I18n.tr("Chips")], ["icons", I18n.tr("Icons")]],
        "sized": true,
        "def": { "style": "chips", "size": "M" },
        "options": [
            { "key": "battery", "name": I18n.tr("Battery"), "type": "bool", "def": true },
            { "key": "network", "name": I18n.tr("Network"), "type": "bool", "def": true },
            { "key": "bluetooth", "name": I18n.tr("Bluetooth"), "type": "bool", "def": true },
            { "key": "dnd", "name": I18n.tr("Do not disturb"), "type": "bool", "def": true, "where": "lock" },
            { "key": "keyboard", "name": I18n.tr("Keyboard layout"), "type": "bool", "def": true }
        ]
    },
    {
        "id": "power",
        "name": I18n.tr("Power"),
        "icon": "power_settings_new",
        "where": "both",
        "blurb": I18n.tr("Suspend, restart and shut down, each asking first when it would end something"),
        "styles": [["bar", I18n.tr("Bar")], ["round", I18n.tr("Round buttons")]],
        "sized": true,
        "def": { "style": "bar", "size": "M" },
        "options": [
            { "key": "suspend", "name": I18n.tr("Suspend"), "type": "bool", "def": true },
            { "key": "hibernate", "name": I18n.tr("Hibernate"), "type": "bool", "def": true },
            { "key": "logout", "name": I18n.tr("Log out"), "type": "bool", "def": true, "where": "lock" },
            { "key": "reboot", "name": I18n.tr("Restart"), "type": "bool", "def": true },
            { "key": "shutdown", "name": I18n.tr("Shut down"), "type": "bool", "def": true }
        ]
    },
    {
        "id": "message",
        "name": I18n.tr("Message"),
        "icon": "info",
        "where": "both",
        "blurb": I18n.tr("A line of your own, such as who to call if this is found"),
        "styles": [["plain", I18n.tr("Plain")], ["card", I18n.tr("Card")]],
        "sized": true,
        "def": { "style": "plain", "size": "M" },
        "options": [
            { "key": "text", "name": I18n.tr("Text"), "type": "text", "def": "" },
            { "key": "icon", "name": I18n.tr("Icon"), "type": "choice", "def": "info", "choices": [["info", I18n.tr("Info")], ["favorite", I18n.tr("Heart")], ["home", I18n.tr("Home")], ["call", I18n.tr("Phone")], ["mail", I18n.tr("Mail")], ["star", I18n.tr("Star")], ["none", I18n.tr("None")]] }
        ]
    },
    {
        "id": "media",
        "name": I18n.tr("Media"),
        "icon": "music_note",
        "where": "lock",
        "blurb": I18n.tr("Whatever is playing, with play, pause and skip"),
        "styles": [["card", I18n.tr("Card")], ["compact", I18n.tr("Compact")], ["cover", I18n.tr("Cover")], ["deck", I18n.tr("Deck")]],
        "sized": false,
        "def": { "style": "card" }
    },
    {
        "id": "notifications",
        "name": I18n.tr("Notifications"),
        "icon": "notifications",
        "where": "lock",
        "blurb": I18n.tr("What came in while you were away"),
        "styles": [["list", I18n.tr("List")], ["icons", I18n.tr("Icons")], ["count", I18n.tr("Count")]],
        "sized": false,
        "def": { "style": "list" },
        "options": [
            { "key": "private", "name": I18n.tr("Hide what they say"), "type": "bool", "def": false, "styles": ["list"] }
        ]
    },
    {
        "id": "agenda",
        "name": I18n.tr("Up next"),
        "icon": "alarm",
        "where": "lock",
        "blurb": I18n.tr("Your next reminder and the next alarm"),
        "styles": [["line", I18n.tr("Line")], ["card", I18n.tr("Card")]],
        "sized": false,
        "def": { "style": "line" }
    }
];

function preset(id) {
    for (var i = 0; i < presets.length; i++) {
        if (presets[i].id === id)
            return presets[i];

    }
    return presets[0];
}

function widget(id) {
    for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].id === id)
            return widgets[i];

    }
    return null;
}

function slotOf(p, id) {
    var slots = preset(p).slots;
    for (var i = 0; i < slots.length; i++) {
        if (slots[i].id === id)
            return slots[i];

    }
    return null;
}

function hasSlot(p, id) {
    return slotOf(p, id) !== null;
}

// a preset's slots as the user filled them: known slots, known widgets,
// each widget once. anything else in the saved text is dropped quietly
function cleanSlots(p, raw) {
    var src = (raw && typeof raw === "object") ? raw : preset(p).defaults;
    var out = {}, seen = {};
    var slots = preset(p).slots;
    for (var i = 0; i < slots.length; i++) {
        var list = Array.isArray(src[slots[i].id]) ? src[slots[i].id] : [];
        var keep = [];
        for (var j = 0; j < list.length && keep.length < 8; j++) {
            var w = String(list[j]);
            if (widget(w) && !seen[w]) {
                seen[w] = true;
                keep.push(w);
            }
        }
        out[slots[i].id] = keep;
    }
    return out;
}

function parse(text, fallback) {
    if (!text)
        return fallback;

    try {
        var v = JSON.parse(text);
        return (v && typeof v === "object") ? v : fallback;
    } catch (e) {
        return fallback;
    }
}

function clamp(v, lo, hi, def) {
    var n = Number(v);
    return isNaN(n) ? def : Math.max(lo, Math.min(hi, n));
}

// the whole layout from what Prefs keeps: a preset, every preset's slots, the
// widgets' options and the backdrop. what the login screen is sent is the
// result of this, for the one preset in use
function build(presetId, slotsText, optsText, extra) {
    var p = preset(presetId).id;
    var all = parse(slotsText, {});
    var opts = parse(optsText, {});
    var e = extra || {};
    return {
        "preset": p,
        "slots": cleanSlots(p, all[p]),
        "opts": opts,
        "blur": clamp(e.blur, 0, 100, 50),
        "dim": clamp(e.dim, 0, 100, 40),
        "tint": e.tint === undefined ? true : !!e.tint,
        "other": e.other === "blank" ? "blank" : "clock"
    };
}

// the same, from a layout that already went through build() once, as the
// login screen receives it. never trust it further than that
function rebuild(obj) {
    var o = (obj && typeof obj === "object") ? obj : {};
    var p = preset(o.preset).id;
    var all = {};
    // a layout with no slots at all is a damaged one, not an empty screen
    if (o.slots && typeof o.slots === "object" && Object.keys(o.slots).length > 0)
        all[p] = o.slots;
    return build(p, JSON.stringify(all), JSON.stringify(o.opts && typeof o.opts === "object" ? o.opts : {}), o);
}

// a widget's option, in order of say: the user's, the preset's, the widget's
function opt(layout, type, key) {
    var w = widget(type);
    var mine = (layout && layout.opts && layout.opts[type]) || {};
    if (mine[key] !== undefined && valid(w, key, mine[key]))
        return mine[key];

    var pre = (preset(layout ? layout.preset : "").opts || {})[type] || {};
    if (pre[key] !== undefined)
        return pre[key];

    if (w && w.def && w.def[key] !== undefined)
        return w.def[key];

    var o = optionOf(w, key);
    return o ? o.def : undefined;
}

function optionOf(w, key) {
    if (!w || !w.options)
        return null;

    for (var i = 0; i < w.options.length; i++) {
        if (w.options[i].key === key)
            return w.options[i];

    }
    return null;
}

function valid(w, key, v) {
    if (!w)
        return false;

    if (key === "style")
        return w.styles.some(function(s) {
            return s[0] === v;
        });

    if (key === "size")
        return sizes.some(function(s) {
            return s[0] === v;
        });

    var o = optionOf(w, key);
    if (!o)
        return false;

    if (o.type === "bool")
        return typeof v === "boolean";

    if (o.type === "text")
        return typeof v === "string" && v.length <= 160;

    if (o.type === "choice")
        return o.choices.some(function(c) {
            return c[0] === v;
        });

    return false;
}

// a preset's own option, kept with the widgets' under the preset's id
function presetOpt(layout, key) {
    var p = preset(layout ? layout.preset : "");
    var mine = (layout && layout.opts && layout.opts[p.id]) || {};
    var list = p.options || [];
    for (var i = 0; i < list.length; i++) {
        if (list[i].key !== key)
            continue;

        var v = mine[key];
        var ok = list[i].type === "choice" ? list[i].choices.some(function(c) {
            return c[0] === v;
        }) : typeof v === typeof list[i].def;
        return ok ? v : list[i].def;
    }
    return undefined;
}

// clock units as a share of the screen's height, by size
function clockUnit(size, h) {
    var k = ({
        "S": 0.085,
        "M": 0.115,
        "L": 0.155,
        "XL": 0.2
    })[size] || 0.155;
    return Math.round(h * k);
}

// everything else grows less than the clock does
function sizeK(size) {
    return ({
        "S": 0.86,
        "M": 1,
        "L": 1.16,
        "XL": 1.32
    })[size] || 1;
}

function shownOn(type, greeter) {
    var w = widget(type);
    return !!w && (!greeter || w.where !== "lock");
}

// ── edits, for the settings. each returns a new slots object ────────────────
function without(slots, type) {
    var out = {};
    for (var k in slots)
        out[k] = slots[k].filter(function(x) {
            return x !== type;
        });

    return out;
}

function placed(slots, type) {
    for (var k in slots) {
        if (slots[k].indexOf(type) !== -1)
            return k;

    }
    return "";
}

function withWidget(slots, slot, type, index) {
    var out = without(slots, type);
    var list = (out[slot] || []).slice();
    var at = (index === undefined || index < 0 || index > list.length) ? list.length : index;
    list.splice(at, 0, type);
    out[slot] = list;
    return out;
}
