.pragma library

// Wallpaper transitions as plain data: the named presets, the ones a user saved,
// and the transition.conf text set-wallpaper.sh reads. Kept free of Prefs so it
// can be tested on its own; WallTransitions.qml is the part that touches prefs.

var defaults = {
    "type": "fade",
    "duration": 1,
    "angle": 45,
    "origin": "center",
    "bezier": ".54,0,.34,.99",
    "wave": "20,20"
};

var keys = ["type", "duration", "angle", "origin", "bezier", "wave"];

function make(id, name, over) {
    var p = {"id": id, "name": name, "custom": false};
    for (var i = 0; i < keys.length; i++)
        p[keys[i]] = over && over[keys[i]] !== undefined ? over[keys[i]] : defaults[keys[i]];
    return p;
}

var builtIn = [
    make("soft", "Soft", {}),
    make("circle", "Circle", {"type": "grow", "duration": 1.2, "origin": "card"}),
    make("sweep", "Sweep", {"type": "wipe"}),
    make("wave", "Wave", {"type": "wave", "duration": 1.4}),
    make("instant", "Instant", {"type": "none"}),
    make("random", "Random", {"type": "random"})
];

function parseCustom(json) {
    var out = [];
    var raw;
    try {
        raw = JSON.parse(json);
    } catch (e) {
        return out;
    }
    if (!Array.isArray(raw))
        return out;
    for (var i = 0; i < raw.length; i++) {
        var r = raw[i];
        if (!r || typeof r !== "object" || typeof r.id !== "string" || typeof r.name !== "string" || typeof r.type !== "string")
            continue;
        var p = make(r.id, r.name, r);
        p.custom = true;
        out.push(p);
    }
    return out;
}

function presets(customJson) {
    return builtIn.concat(parseCustom(customJson));
}

function presetById(id, customJson) {
    var all = presets(customJson);
    for (var i = 0; i < all.length; i++)
        if (all[i].id === id)
            return all[i];
    return null;
}

function addCustom(customJson, name, values) {
    var list = parseCustom(customJson).map(function (p) {
        return storable(p);
    });
    var id = "u" + Date.now().toString(36) + list.length;
    list.push(storable(make(id, name, values)));
    return JSON.stringify(list);
}

function removeCustom(customJson, id) {
    return JSON.stringify(parseCustom(customJson).filter(function (p) {
        return p.id !== id;
    }).map(storable));
}

function storable(p) {
    var o = {"id": p.id, "name": p.name};
    for (var i = 0; i < keys.length; i++)
        o[keys[i]] = p[keys[i]];
    return o;
}

function same(a, b) {
    for (var i = 0; i < keys.length; i++)
        if (String(a[keys[i]]) !== String(b[keys[i]]))
            return false;
    return true;
}

// the preset whose values are exactly these, or "custom"
function matchingId(values, customJson) {
    var all = presets(customJson);
    for (var i = 0; i < all.length; i++)
        if (same(all[i], values))
            return all[i].id;
    return "custom";
}

// the body of transition.conf. A value with a line break would write a second
// key, so it falls back to the default instead
function confText(v) {
    var out = "";
    for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var val = String(v[k] === undefined ? defaults[k] : v[k]);
        if (/[\r\n]/.test(val))
            val = String(defaults[k]);
        out += k.toUpperCase() + "=" + val + "\n";
    }
    return out;
}
