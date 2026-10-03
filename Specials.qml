import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the apps picked in settings, rendered into lucid-specials.lua for modules/specials.lua
Singleton {
    id: root

    readonly property string dataPath: Quickshell.env("HOME") + "/.config/hypr/lucid-specials.lua"
    readonly property string modulePath: Quickshell.env("HOME") + "/.config/hypr/modules/specials.lua"
    property bool moduleInstalled: false
    property bool moduleProbed: false

    // the keys match modules/binds.lua, and show until keybinds.json is read
    readonly property var builtinSpaces: [
        { "key": "special", "glyph": "layers", "label": "Scratchpad", "pref": "specialScratchpad", "apps": "", "keys": ["Super", "Shift", "S"] },
        { "key": "music", "glyph": "music_note", "label": "Music", "pref": "specialMusic", "apps": "specialMusicApps", "keys": ["Super", "Shift", "M"] },
        { "key": "comms", "glyph": "chat", "label": "Comms", "pref": "specialComms", "apps": "specialCommsApps", "keys": ["Super", "Shift", "D"] },
        { "key": "todo", "glyph": "checklist", "label": "To-do", "pref": "specialTodo", "apps": "specialTodoApps", "keys": ["Super", "Shift", "R"] },
        { "key": "sysmon", "glyph": "monitor_heart", "label": "System", "pref": "specialSysmon", "apps": "specialSysmonApps", "keys": ["Ctrl", "Shift", "Escape"] }
    ]
    readonly property var stashKeys: ["Super", "Alt", "S"]
    // the ones made in settings, after the ones lucid ships
    readonly property var ownSpaces: {
        let list = [];
        try {
            list = JSON.parse(Prefs.specialCustom || "[]");
        } catch (e) {
            list = [];
        }
        if (!Array.isArray(list))
            return [];

        const seen = {};
        return list.filter((w) => {
            if (!w || typeof w.key !== "string" || !root.keyPattern.test(w.key) || root.reserved.indexOf(w.key) !== -1 || seen[w.key])
                return false;

            seen[w.key] = true;
            return true;
        }).map((w) => {
            return {
                "key": w.key,
                "glyph": root.glyphs[w.glyph] ? w.glyph : "apps",
                "label": String(w.label || w.key),
                "on": w.on !== false,
                "apps": typeof w.apps === "string" ? w.apps : "",
                "own": true
            };
        });
    }
    readonly property var spaces: root.builtinSpaces.concat(root.ownSpaces)
    // a key is also the lua table key and the hyprland name, special:<key>
    readonly property var keyPattern: /^[a-z][a-z0-9_]{0,23}$/
    readonly property var reserved: ["special", "music", "comms", "todo", "sysmon", "minimized", "scratchpad"]
    // apps the catalogue below does not know are stored as entry:<desktop id>
    readonly property string customPrefix: "entry:"
    // wrappers, so an added app's class guess does not take the launcher for the app
    readonly property var execWrappers: ["flatpak", "snap", "env", "sh", "bash", "zsh", "dbus-run-session", "systemd-run", "gtk-launch", "python", "python3", "wine"]

    // material symbol names, drawn by Icon
    readonly property var glyphs: ({
        "web": "web",
        "mail": "mail",
        "chat": "chat",
        "print": "print",
        "security": "security",
        "archive": "archive",
        "code": "code",
        "edit_note": "edit_note",
        "music_note": "music_note",
        "mic": "mic",
        "sports_esports": "sports_esports",
        "folder": "folder",
        "settings": "settings",
        "monitor_heart": "monitor_heart",
        "terminal": "terminal",
        "build": "build",
        "graphic_eq": "graphic_eq",
        "movie": "movie",
        "videocam": "videocam",
        "photo_library": "photo_library",
        "tv": "tv",
        "host": "host",
        "content_paste": "content_paste",
        "checklist": "checklist",
        "layers": "layers",
        "apps": "apps"
    })
    // a window's desktop-entry Categories pick its glyph, first match wins, so
    // the order is the priority. ported from caelestia's Icons.qml categoryIcons
    readonly property var categoryGlyphs: [
        ["WebBrowser", "web"],
        ["Email", "mail"],
        ["InstantMessaging", "chat"],
        ["IRCClient", "chat"],
        ["Printing", "print"],
        ["Security", "security"],
        ["Network", "chat"],
        ["Archiving", "archive"],
        ["Compression", "archive"],
        ["Development", "code"],
        ["IDE", "code"],
        ["TextEditor", "edit_note"],
        ["Audio", "music_note"],
        ["Music", "music_note"],
        ["Player", "music_note"],
        ["Recorder", "mic"],
        ["Game", "sports_esports"],
        ["FileTools", "folder"],
        ["FileManager", "folder"],
        ["Filesystem", "folder"],
        ["FileTransfer", "folder"],
        ["Settings", "settings"],
        ["DesktopSettings", "settings"],
        ["HardwareSettings", "settings"],
        // ahead of the terminal rows: btop and htop are System;Monitor;ConsoleOnly
        ["Monitor", "monitor_heart"],
        ["TerminalEmulator", "terminal"],
        ["ConsoleOnly", "terminal"],
        ["ProjectManagement", "checklist"],
        ["Utility", "build"],
        ["Midi", "graphic_eq"],
        ["Mixer", "graphic_eq"],
        ["AudioVideoEditing", "movie"],
        ["AudioVideo", "movie"],
        ["Video", "videocam"],
        ["Building", "build"],
        ["Graphics", "photo_library"],
        ["2DGraphics", "photo_library"],
        ["RasterGraphics", "photo_library"],
        ["TV", "tv"],
        ["System", "host"],
        ["Office", "content_paste"]
    ]

    // ids: desktop entries, native before flatpak. class: case-blind. title: builds with no class
    readonly property var catalog: ({
        "music": [
            { "id": "spotify", "name": "Spotify", "ids": ["spotify", "com.spotify.Client", "spotify-launcher"], "class": ["spotify"], "title": ["Spotify", "Spotify Free", "Spotify Premium"] },
            { "id": "feishin", "name": "Feishin", "ids": ["feishin", "org.jeffvli.feishin"], "class": ["feishin"] },
            { "id": "supersonic", "name": "Supersonic", "ids": ["supersonic-desktop", "supersonic", "io.github.dweymouth.supersonic"], "class": ["supersonic"] },
            { "id": "cider", "name": "Cider", "ids": ["cider", "sh.cider.Cider", "sh.cider.genten"], "class": ["cider"] },
            { "id": "ytmusic", "name": "YouTube Music", "ids": ["youtube-music", "com.github.th-ch.youtube-music", "youtube-music-desktop-app"], "class": ["com.github.th-ch.youtube-music", "youtube-music", "youtube music"] },
            { "id": "tidal", "name": "TIDAL Hi-Fi", "ids": ["tidal-hifi", "com.mastermindzh.tidal-hifi"], "class": ["tidal-hifi"] },
            { "id": "plexamp", "name": "Plexamp", "ids": ["plexamp", "com.plexamp.Plexamp"], "class": ["plexamp"] },
            { "id": "amberol", "name": "Amberol", "ids": ["io.bassi.Amberol"], "class": ["io.bassi.amberol"] },
            { "id": "rhythmbox", "name": "Rhythmbox", "ids": ["org.gnome.Rhythmbox3"], "class": ["rhythmbox", "org.gnome.rhythmbox3"] },
            { "id": "strawberry", "name": "Strawberry", "ids": ["org.strawberrymusicplayer.strawberry"], "class": ["strawberry", "org.strawberrymusicplayer.strawberry"] },
            { "id": "elisa", "name": "Elisa", "ids": ["org.kde.elisa"], "class": ["elisa", "org.kde.elisa"] }
        ],
        "comms": [
            { "id": "discord", "name": "Discord", "ids": ["discord", "com.discordapp.Discord"], "class": ["discord"] },
            { "id": "vesktop", "name": "Vesktop", "ids": ["vesktop", "dev.vencord.Vesktop"], "class": ["vesktop"] },
            { "id": "equibop", "name": "Equibop", "ids": ["equibop", "io.github.equicord.equibop"], "class": ["equibop"] },
            { "id": "legcord", "name": "Legcord", "ids": ["legcord", "app.legcord.Legcord"], "class": ["legcord"] },
            { "id": "telegram", "name": "Telegram", "ids": ["org.telegram.desktop", "telegramdesktop"], "class": ["org.telegram.desktop", "telegramdesktop", "telegram-desktop"] },
            { "id": "signal", "name": "Signal", "ids": ["signal-desktop", "org.signal.Signal", "signal"], "class": ["signal", "signal-desktop"] },
            { "id": "element", "name": "Element", "ids": ["element-desktop", "im.riot.Riot", "io.element.Element"], "class": ["element"] },
            { "id": "zapzap", "name": "ZapZap", "ids": ["com.rtosta.zapzap", "zapzap"], "class": ["com.rtosta.zapzap", "zapzap"] },
            { "id": "wasistlos", "name": "WasIstLos", "ids": ["com.github.xeco23.WasIstLos", "wasistlos", "whatsapp-for-linux"], "class": ["wasistlos", "com.github.xeco23.wasistlos", "whatsapp-for-linux"] },
            { "id": "slack", "name": "Slack", "ids": ["slack", "com.slack.Slack"], "class": ["slack"] },
            { "id": "teams", "name": "Teams for Linux", "ids": ["teams-for-linux", "com.github.IsmaelMartinez.teams_for_linux"], "class": ["teams-for-linux"] },
            { "id": "thunderbird", "name": "Thunderbird", "ids": ["org.mozilla.Thunderbird", "thunderbird"], "class": ["thunderbird", "org.mozilla.thunderbird"] }
        ],
        "todo": [
            { "id": "todoist", "name": "Todoist", "ids": ["todoist", "com.todoist.Todoist"], "class": ["todoist"] },
            { "id": "planify", "name": "Planify", "ids": ["io.github.alainm23.planify"], "class": ["io.github.alainm23.planify"] },
            { "id": "errands", "name": "Errands", "ids": ["io.github.mrvladus.Errands"], "class": ["io.github.mrvladus.errands"] },
            { "id": "endeavour", "name": "Endeavour", "ids": ["org.gnome.Todo"], "class": ["org.gnome.todo", "gnome-todo"] },
            { "id": "superproductivity", "name": "Super Productivity", "ids": ["superproductivity", "com.super_productivity.SuperProductivity"], "class": ["superproductivity"] },
            { "id": "obsidian", "name": "Obsidian", "ids": ["obsidian", "md.obsidian.Obsidian"], "class": ["obsidian"] },
            { "id": "logseq", "name": "Logseq", "ids": ["logseq", "com.logseq.Logseq"], "class": ["logseq"] }
        ],
        "sysmon": [
            { "id": "btop", "name": "btop", "ids": ["btop"], "term": "btop", "class": ["lucid.btop"] },
            { "id": "htop", "name": "htop", "ids": ["htop"], "term": "htop", "class": ["lucid.htop"] },
            { "id": "missioncenter", "name": "Mission Center", "ids": ["io.missioncenter.MissionCenter"], "class": ["io.missioncenter.missioncenter"] },
            { "id": "resources", "name": "Resources", "ids": ["net.nokyan.Resources"], "class": ["net.nokyan.resources"] },
            { "id": "gnomesysmon", "name": "System Monitor", "ids": ["org.gnome.SystemMonitor", "gnome-system-monitor"], "class": ["gnome-system-monitor", "org.gnome.systemmonitor"] },
            { "id": "plasmasysmon", "name": "System Monitor", "ids": ["org.kde.plasma-systemmonitor"], "class": ["org.kde.plasma-systemmonitor", "plasma-systemmonitor"] }
        ]
    })

    // touch this in a binding that calls a lookup, so it re-runs as entries land
    readonly property int entryCount: DesktopEntries.applications.values.length

    // desktop entries arrive over a few seconds, so this settles late
    readonly property var available: {
        void DesktopEntries.applications.values.length;
        const out = {};
        for (const ws in root.catalog) {
            out[ws] = root.catalog[ws].filter((app) => {
                return root.entryOf(app) !== null;
            });
        }
        return out;
    }

    function entryOf(app) {
        for (const id of app.ids) {
            const e = DesktopEntries.byId(id);
            if (e)
                return e;

        }
        return null;
    }

    function space(key) {
        return root.spaces.find((s) => {
            return s.key === key;
        }) || null;
    }

    function appById(ws, id) {
        if (root.isCustom(id))
            return root.customApp(id);

        return (root.catalog[ws] || []).find((a) => {
            return a.id === id;
        }) || null;
    }

    function isCustom(id) {
        return String(id).indexOf(root.customPrefix) === 0;
    }

    // a terminal app takes the class the launcher is told to give it, dotted so
    // ghostty accepts it as an app id
    function termClass(entryId) {
        return "lucid." + String(entryId).toLowerCase().replace(/[^a-z0-9]+/g, "-");
    }

    // any installed app in the shape of a catalogue one. the class is a guess:
    // the desktop id for most toolkits, the program name otherwise, and
    // StartupWMClass on top of both in appLua
    function customApp(id) {
        const entryId = String(id).slice(root.customPrefix.length);
        const e = DesktopEntries.byId(entryId);
        if (!e)
            return null;

        const classes = [entryId];
        const prog = (e.command || [])[0];
        if (prog) {
            const base = String(prog).split("/").pop();
            if (base !== "" && root.execWrappers.indexOf(base) === -1 && base.toLowerCase() !== entryId.toLowerCase())
                classes.push(base);

        }
        return {
            "id": id,
            "name": e.name || entryId,
            "ids": [entryId],
            "class": e.runInTerminal ? [root.termClass(entryId)] : classes,
            "custom": true
        };
    }

    function runsInTerm(app, entry) {
        return app.term ? true : (app.custom === true && entry.runInTerminal === true);
    }

    // everything installed that the page does not already list for this workspace
    function installedApps(ws) {
        const taken = {};
        for (const a of root.catalog[ws] || []) {
            const e = root.entryOf(a);
            if (e)
                taken[e.id] = true;

        }
        for (const id of root.chosen(ws)) {
            if (root.isCustom(id))
                taken[String(id).slice(root.customPrefix.length)] = true;

        }
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || taken[e.id])
                continue;

            out.push({
                "id": e.id,
                "name": e.name || e.id,
                "icon": e.icon ? Quickshell.iconPath(e.icon, true) : "",
                "note": e.genericName || e.comment || ""
            });
        }
        out.sort((a, b) => {
            const x = a.name.toLowerCase();
            const y = b.name.toLowerCase();
            return x < y ? -1 : (x > y ? 1 : 0);
        });
        return out;
    }

    function addApp(ws, entryId) {
        root.setChosen(ws, root.customPrefix + entryId, true);
    }

    function isOn(key) {
        const s = root.space(key);
        if (s && s.own)
            return s.on;

        return s ? Prefs[s.pref] !== false : true;
    }

    function setOn(key, on) {
        const s = root.space(key);
        if (s && s.own)
            root.editOwn(key, {
            "on": on
        });
        else if (s)
            Prefs.set(s.pref, on);
    }

    function isOwn(key) {
        const s = root.space(key);
        return s !== null && s.own === true;
    }

    function saveOwn(list) {
        Prefs.specialCustom = JSON.stringify(list.map((w) => {
            return {
                "key": w.key,
                "label": w.label,
                "glyph": w.glyph,
                "on": w.on,
                "apps": w.apps
            };
        }));
    }

    function editOwn(key, change) {
        root.saveOwn(root.ownSpaces.map((w) => {
            return w.key === key ? Object.assign({}, w, change) : w;
        }));
    }

    // Música -> musica; anything with no latin letters falls back to space
    function keyFor(label) {
        let base = String(label || "");
        try {
            base = base.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        } catch (e) {
        }
        base = base.toLowerCase().replace(/[^a-z0-9]+/g, "_").substring(0, 20).replace(/^[^a-z]+|_+$/g, "");
        if (base === "")
            base = "space";

        let key = base;
        for (let n = 2; root.space(key) !== null || root.reserved.indexOf(key) !== -1; n++) key = base + n
        return key;
    }

    // returns the new workspace's key
    function create(label, glyph) {
        const name = String(label || "").trim();
        if (name === "")
            return "";

        const key = root.keyFor(name);
        root.saveOwn(root.ownSpaces.concat([{
            "key": key,
            "label": name,
            "glyph": root.glyphs[glyph] ? glyph : "apps",
            "on": true,
            "apps": ""
        }]));
        return key;
    }

    // the key stays, so the workspace and its bind carry over a rename
    function rename(key, label, glyph) {
        const name = String(label || "").trim();
        if (name === "" || !root.isOwn(key))
            return ;

        const old = root.space(key).label;
        root.editOwn(key, {
            "label": name,
            "glyph": root.glyphs[glyph] ? glyph : "apps"
        });
        // a description you wrote yourself is left alone
        const b = root.bindOf(key);
        if (b && b.desc === root.bindDesc(old))
            Keybinds.upsert(Object.assign({}, b, {
            "desc": root.bindDesc(name)
        }));

    }

    // its windows come back to the workspace you are on, and its key goes with it
    function remove(key) {
        if (!root.isOwn(key))
            return ;

        Quickshell.execDetached(["hyprctl", "eval", "if LucidSpecials then LucidSpecials.release(" + root.luaStr(key) + ") end"]);
        const b = root.bindOf(key);
        if (b)
            Keybinds.remove(b.id);

        root.saveOwn(root.ownSpaces.filter((w) => {
            return w.key !== key;
        }));
    }

    function bindDesc(label) {
        return label + " workspace";
    }

    function bindLua(key) {
        return key === "special" ? "specials.scratchpad()" : "specials.toggle(" + JSON.stringify(key) + ")";
    }

    // the bind that opens a workspace, found by what it runs so an edited or
    // hand-written one counts too
    function bindOf(key) {
        const want = root.bindLua(key).replace(/\s+/g, "").replace(/'/g, "\"");
        for (const b of Keybinds.binds) {
            if (b.type === "lua" && String(b.lua || "").replace(/\s+/g, "").replace(/'/g, "\"") === want)
                return b;

        }
        return null;
    }

    // a bind for the key editor to start from, keys still to be pressed
    function newBind(key) {
        const s = root.space(key);
        return {
            "keys": "",
            "desc": root.bindDesc(s ? s.label : key),
            "category": "Workspaces",
            "type": "lua",
            "lua": root.bindLua(key)
        };
    }

    // what opens it, as keycaps: [] when nothing does
    function keysOf(key) {
        const s = root.space(key);
        if (!Keybinds.loaded || Keybinds.missing)
            return s && s.keys ? s.keys : [];

        const b = root.bindOf(key);
        return b && b.enabled !== false && b.keys ? Keybinds.tokens(b.keys) : [];
    }

    // "auto" means the first one installed
    function chosen(ws) {
        const s = root.space(ws);
        if (!s || (s.apps === "" && !s.own))
            return [];

        const raw = s.own ? s.apps : Prefs[s.apps];
        const avail = root.available[ws] || [];
        if (raw === "auto")
            return avail.length > 0 ? [avail[0].id] : [];

        return Prefs.splitList(raw).filter((id) => {
            if (root.isCustom(id))
                return root.customApp(id) !== null;

            return avail.some((a) => {
                return a.id === id;
            });
        });
    }

    function isChosen(ws, id) {
        return root.chosen(ws).indexOf(id) !== -1;
    }

    function setChosen(ws, id, on) {
        const s = root.space(ws);
        if (!s || (s.apps === "" && !s.own))
            return ;

        const list = root.chosen(ws).filter((x) => {
            return x !== id;
        });
        if (on)
            list.push(id);

        const order = (root.catalog[ws] || []).map((a) => {
            return a.id;
        });
        const known = list.filter((x) => {
            return order.indexOf(x) !== -1;
        }).sort((a, b) => {
            return order.indexOf(a) - order.indexOf(b);
        });
        const added = list.filter((x) => {
            return order.indexOf(x) === -1;
        });
        const value = known.concat(added).join(",");
        if (s.own)
            root.editOwn(ws, {
            "apps": value
        });
        else
            Prefs.set(s.apps, value);
    }

    function chosenNames(ws) {
        return root.chosen(ws).map((id) => {
            const a = root.appById(ws, id);
            return a ? a.name : id;
        });
    }

    function iconOf(ws, id) {
        const a = root.appById(ws, id);
        const e = a ? root.entryOf(a) : null;
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    function keysText(keys) {
        return keys.join(" + ");
    }

    // special:music -> Music
    function label(name) {
        const bare = String(name).indexOf("special:") === 0 ? String(name).slice(8) : String(name);
        const s = root.space(bare);
        return s ? s.label : (bare === "" ? "special" : bare);
    }

    // special:music -> the workspace's own mark
    function glyph(name) {
        const bare = String(name).indexOf("special:") === 0 ? String(name).slice(8) : String(name);
        const s = root.space(bare);
        return s && s.glyph ? s.glyph : "apps";
    }

    // terminal apps run under a forced lucid.<id> class
    function entryForClass(cls) {
        const c = String(cls || "");
        if (c === "")
            return null;

        const bare = c.indexOf("lucid.") === 0 ? c.slice(6) : c;
        return DesktopEntries.heuristicLookup(bare) || DesktopEntries.heuristicLookup(c) || null;
    }

    // a stashed window's mark: its entry's category, else the workspace's own
    function appGlyph(cls, wsName) {
        const e = root.entryForClass(cls);
        const cats = e && e.categories ? e.categories : [];
        if (cats.length > 0) {
            for (const pair of root.categoryGlyphs) {
                if (cats.indexOf(pair[0]) !== -1)
                    return pair[1];

            }
        }
        return root.glyph(wsName);
    }

    function glyphName(name) {
        return root.glyphs[name] || "apps";
    }

    function order(name) {
        const bare = String(name).indexOf("special:") === 0 ? String(name).slice(8) : String(name);
        const i = root.spaces.findIndex((s) => {
            return s.key === bare;
        });
        return i === -1 ? root.spaces.length : i;
    }

    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r") + "\"";
    }

    function luaList(list) {
        return "{ " + list.map(root.luaStr).join(", ") + " }";
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function termCommand(argv, cls) {
        const p = argv.map(root.shQuote).join(" ");
        const c = root.shQuote(cls);
        return "if command -v kitty >/dev/null 2>&1; then exec kitty --class " + c + " -e " + p + "; " + "elif command -v foot >/dev/null 2>&1; then exec foot --app-id=" + c + " " + p + "; " + "elif command -v alacritty >/dev/null 2>&1; then exec alacritty --class " + c + " -e " + p + "; " + "elif command -v ghostty >/dev/null 2>&1; then exec ghostty --class=" + c + " -e " + p + "; fi";
    }

    // exec keeps the pid that launch rules go by; drops flags a field code left empty (--uri=)
    function launchCommand(app, entry) {
        if (app.term)
            return root.termCommand([app.term], app.class[0]);

        const argv = (entry.command || []).filter((a) => {
            return !/^--?[A-Za-z0-9_-]+=$/.test(a);
        });
        if (argv.length === 0)
            return "";

        if (root.runsInTerm(app, entry))
            return root.termCommand(argv, app.class[0]);

        return "exec " + argv.map(root.shQuote).join(" ");
    }

    function appLua(ws, id) {
        const app = root.appById(ws, id);
        const entry = app ? root.entryOf(app) : null;
        if (!entry)
            return "";

        const classes = app.class.slice();
        if (!root.runsInTerm(app, entry) && entry.startupClass && !classes.some((c) => {
            return c.toLowerCase() === entry.startupClass.toLowerCase();
        }))
            classes.push(entry.startupClass);

        let out = "{ name = " + root.luaStr(app.name) + ", cmd = " + root.luaStr(root.launchCommand(app, entry)) + ", class = " + root.luaList(classes);
        if (app.title && app.title.length > 0)
            out += ", title = " + root.luaList(app.title);

        return out + " }";
    }

    readonly property string rendered: {
        let out = "-- written by Lucid Settings > Workspaces, and rewritten on every change there\n";
        out += "return {\n";
        out += "    keep = " + (Prefs.specialKeepApps ? "true" : "false") + ",\n";
        out += "    hide_on_switch = " + (Prefs.specialHideOnSwitch ? "true" : "false") + ",\n";
        out += "    dim = " + Math.round(Prefs.specialDim * 100) / 100 + ",\n";
        out += "    blur = " + (Prefs.specialBlur ? "true" : "false") + ",\n";
        out += "    gaps = " + Math.max(0, Math.round(Prefs.specialGaps)) + ",\n";
        out += "    workspaces = {\n";
        for (const s of root.spaces) {
            const apps = root.chosen(s.key).map((id) => {
                return root.appLua(s.key, id);
            }).filter((x) => {
                return x !== "";
            });
            out += "        " + s.key + " = { enabled = " + (root.isOn(s.key) ? "true" : "false") + ", apps = {";
            out += apps.length > 0 ? "\n" + apps.map((a) => {
                return "            " + a + ",\n";
            }).join("") + "        } },\n" : "} },\n";
        }
        out += "    },\n}\n";
        return out;
    }

    function write() {
        if (!Prefs.loaded || !dataFile.ready || root.rendered === dataFile.current)
            return ;

        dataFile.current = root.rendered;
        dataFile.setText(root.rendered);
    }

    Timer {
        id: writeDebounce

        interval: 1200
        repeat: false
        onTriggered: root.write()
    }

    onRenderedChanged: writeDebounce.restart()

    Connections {
        function onLoadedChanged() {
            writeDebounce.restart();
        }

        target: Prefs
    }

    FileView {
        id: dataFile

        property bool ready: false
        property string current: ""

        path: root.dataPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            dataFile.current = dataFile.text();
            dataFile.ready = true;
            writeDebounce.restart();
        }
        onLoadFailed: {
            dataFile.current = "";
            dataFile.ready = true;
            writeDebounce.restart();
        }
        // routing rules live in hyprland, so it re-reads once the file is on disk
        onSaved: Quickshell.execDetached(["hyprctl", "eval", "if LucidSpecials then LucidSpecials.apply() end"])
    }

    // missing after --no-hypr, and the page says so
    FileView {
        path: root.modulePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.moduleInstalled = true;
            root.moduleProbed = true;
        }
        onLoadFailed: {
            root.moduleInstalled = false;
            root.moduleProbed = true;
        }
    }

}
