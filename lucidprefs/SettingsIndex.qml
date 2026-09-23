import QtQuick
import Quickshell
import Quickshell.Io

// what Settings search looks through: every page's rows, read out of the page
// files themselves so a row added to a page is found without anyone listing it.
// only rows whose title is a plain string are kept; the ones built from live
// state (a network's name, a device's battery) are not settings to look for
Item {
    id: index

    // Settings' own page list, and the file each page loads
    property var pages: []
    property var fileOf: (key) => {
        return "";
    }
    property bool wanted: false
    // words people search for that a page never uses itself
    property var keywords: ({
        "users": "password avatar picture login sign in",
        "general": "accent animation motion rounding corners islands notches",
        "glass": "blur transparency transparent opacity translucent frosted",
        "theme": "palette wallpaper background dark light matugen",
        "environment": "gtk qt cursor icon theme font",
        "bar": "panel status tray top",
        "dock": "taskbar pinned",
        "launcher": "app menu start",
        "widgets": "desktop cards",
        "workspaces": "scratchpad special",
        "keybinds": "shortcuts hotkeys keys keyboard",
        "displays": "monitor monitors screen resolution refresh scale hdmi",
        "sound": "audio volume speakers headphones microphone",
        "network": "internet ethernet wired wireless",
        "bluetooth": "pair headphones airpods",
        "kdeconnect": "kde connect android",
        "notifications": "dnd popups",
        "idle": "lock suspend screen off timeout hypridle",
        "datetime": "clock timezone time zone",
        "about": "version update"
    })
    // { key, card, title, description }, in page order
    property var rows: []

    // read the pages the first time someone searches, not on every open
    function ensure() {
        index.wanted = true;
    }

    function collect() {
        var out = [];
        for (var i = 0; i < files.count; i++) {
            var f = files.objectAt(i);
            if (!f || !f.ready)
                return ;

            out = out.concat(index.parse(f.key, f.text()));
        }
        index.rows = out;
    }

    // a quoted string and nothing else, as JSON reads it; anything else is live
    function literal(v) {
        if (v.charAt(0) !== "\"" || v.charAt(v.length - 1) !== "\"")
            return null;

        try {
            var s = JSON.parse(v);
            return typeof s === "string" ? s : null;
        } catch (e) {
            return null;
        }
    }

    // the files are qmlformat's: a row's own properties sit one step in from its
    // opening line, and its closing brace lines up with it
    function parse(key, text) {
        var lines = text.split("\n");
        var cards = [];
        var out = [];
        for (var i = 0; i < lines.length; i++) {
            var m = /^( *)Setting(Card|Row) \{$/.exec(lines[i]);
            if (!m)
                continue;

            var pad = m[1];
            var inner = pad + "    ";
            var props = {
            };
            var end = i + 1;
            for (; end < lines.length; end++) {
                if (lines[end] === pad + "}")
                    break;

                if (lines[end].indexOf(inner) !== 0 || lines[end].charAt(inner.length) === " ")
                    continue;

                var p = /^(title|description): (.*)$/.exec(lines[end].substring(inner.length));
                if (p && props[p[1]] === undefined)
                    props[p[1]] = index.literal(p[2]);

            }
            if (m[2] === "Card") {
                cards.push({
                    "from": i,
                    "to": end,
                    "title": props.title || ""
                });
                continue;
            }
            if (!props.title)
                continue;

            var card = "";
            for (var c = cards.length - 1; c >= 0; c--) {
                if (cards[c].from < i && cards[c].to > i) {
                    card = cards[c].title;
                    break;
                }
            }
            out.push({
                "key": key,
                "card": card,
                "title": props.title,
                "description": props.description || ""
            });
        }
        return out;
    }

    // lower case; "wi-fi" and "wifi" read the same, and so do "colour" and "color"
    function norm(s) {
        return s.toLowerCase().replace(/[-_.·'’]/g, "").replace(/colour/g, "color").replace(/behaviour/g, "behavior").replace(/favourite/g, "favorite").replace(/centre/g, "center").replace(/grey/g, "gray");
    }

    // how well one field answers one word: a word that starts there beats one
    // buried inside, and a single letter only counts at the start of a word
    function hit(field, word) {
        var f = index.norm(field);
        var at = f.indexOf(word);
        if (at === -1)
            return 0;

        if (at === 0 || /[\s(/]/.test(f.charAt(at - 1)))
            return 2;

        return word.length > 1 ? 1 : 0;
    }

    // every word has to land somewhere, and at least one of them on a field
    // that is the entry's own (`own` fields come first); the title counts most
    function score(fields, words, own) {
        var total = 0;
        var mine = false;
        for (var w = 0; w < words.length; w++) {
            var best = 0;
            for (var f = 0; f < fields.length; f++) {
                var h = index.hit(fields[f].text, words[w]);
                if (h > 0 && fields[f].weight * (h === 2 ? 1 : 0.7) > best) {
                    best = fields[f].weight * (h === 2 ? 1 : 0.7);
                    mine = mine || f < own;
                }
            }
            if (best === 0)
                return 0;

            total += best;
        }
        return mine ? total : 0;
    }

    // one flat list for the results page: each page with a hit, then its rows
    function find(query) {
        var words = index.norm(query).split(/\s+/).filter((w) => {
            return w !== "";
        });
        if (words.length === 0)
            return [];

        var whole = index.norm(query.trim());
        var groups = [];
        var byKey = {
        };
        for (var i = 0; i < index.pages.length; i++) {
            var pg = index.pages[i];
            if (pg.key === "search")
                continue;

            // naming the page outranks naming a row on it
            var s = index.score([{
                "text": pg.title + " " + pg.label,
                "weight": 200
            }, {
                "text": index.keywords[pg.key] || "",
                "weight": 60
            }, {
                "text": pg.blurb,
                "weight": 20
            }], words, 3);
            var g = {
                "key": pg.key,
                "title": pg.title,
                "order": i,
                "score": s,
                "best": s,
                "rows": []
            };
            groups.push(g);
            byKey[pg.key] = g;
        }
        var rows = index.rows;
        for (var r = 0; r < rows.length; r++) {
            var row = rows[r];
            var grp = byKey[row.key];
            if (!grp)
                continue;

            // the page's name helps a row that matched on its own, but does not
            // list every row of a page that is already a result by itself
            var rs = index.score([{
                "text": row.title,
                "weight": 100
            }, {
                "text": row.card,
                "weight": 40
            }, {
                "text": row.description,
                "weight": 20
            }, {
                "text": grp.title,
                "weight": 30
            }], words, 3);
            if (rs === 0)
                continue;

            if (index.norm(row.title).indexOf(whole) === 0)
                rs += 50;

            grp.rows.push({
                "kind": "row",
                "key": row.key,
                "card": row.card,
                "cardLabel": index.pretty(row.card),
                "title": row.title,
                "description": row.description,
                "score": rs,
                "order": r
            });
            grp.best = Math.max(grp.best, rs);
        }
        groups = groups.filter((g) => {
            return g.score > 0 || g.rows.length > 0;
        });
        groups.sort((a, b) => {
            return b.best - a.best || a.order - b.order;
        });
        var out = [];
        for (var k = 0; k < groups.length && out.length < 80; k++) {
            var gr = groups[k];
            out.push({
                "kind": "page",
                "key": gr.key,
                "title": gr.title,
                // named by the search, not only brushed by its blurb
                "matched": gr.score >= 60
            });
            gr.rows.sort((a, b) => {
                return b.score - a.score || a.order - b.order;
            });
            out = out.concat(gr.rows.slice(0, 12));
        }
        return out;
    }

    // a card's title the way SettingCard prints it
    function pretty(title) {
        if (title === "" || title !== title.toUpperCase())
            return title;

        var keep = {
            "VPN": "VPN",
            "WI-FI": "Wi-Fi",
            "KDE": "KDE",
            "DNS": "DNS",
            "IP": "IP",
            "IPV4": "IPv4",
            "IPV6": "IPv6",
            "MAC": "MAC",
            "OSD": "OSD"
        };
        return title.split(" ").map((w, i) => {
            if (keep[w] !== undefined)
                return keep[w];

            var lower = w.toLowerCase();
            return i === 0 ? lower.charAt(0).toUpperCase() + lower.slice(1) : lower;
        }).join(" ");
    }

    Instantiator {
        id: files

        model: index.wanted ? index.pages.filter((p) => {
            return p.key !== "search" && index.fileOf(p.key) !== "";
        }) : []

        delegate: FileView {
            required property var modelData
            readonly property string key: modelData.key
            property bool ready: false

            path: Quickshell.shellPath("lucidprefs/" + index.fileOf(modelData.key))
            onLoaded: {
                ready = true;
                index.collect();
            }
            onLoadFailed: {
                ready = true;
                index.collect();
            }
        }

    }

}
