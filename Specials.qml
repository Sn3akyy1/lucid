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

    // the keys match modules/binds.lua
    readonly property var spaces: [
        { "key": "special", "label": "Scratchpad", "pref": "specialScratchpad", "apps": "", "keys": ["Super", "Shift", "S"] },
        { "key": "music", "label": "Music", "pref": "specialMusic", "apps": "specialMusicApps", "keys": ["Super", "Shift", "M"] },
        { "key": "comms", "label": "Comms", "pref": "specialComms", "apps": "specialCommsApps", "keys": ["Super", "Shift", "D"] },
        { "key": "todo", "label": "To-do", "pref": "specialTodo", "apps": "specialTodoApps", "keys": ["Super", "Shift", "R"] },
        { "key": "sysmon", "label": "System", "pref": "specialSysmon", "apps": "specialSysmonApps", "keys": ["Ctrl", "Shift", "Escape"] }
    ]
    readonly property var stashKeys: ["Super", "Alt", "S"]

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
        return (root.catalog[ws] || []).find((a) => {
            return a.id === id;
        }) || null;
    }

    function isOn(key) {
        const s = root.space(key);
        return s ? Prefs[s.pref] !== false : true;
    }

    function setOn(key, on) {
        const s = root.space(key);
        if (s)
            Prefs.set(s.pref, on);

    }

    // "auto" means the first one installed
    function chosen(ws) {
        const s = root.space(ws);
        if (!s || s.apps === "")
            return [];

        const raw = Prefs[s.apps];
        const avail = root.available[ws] || [];
        if (raw === "auto")
            return avail.length > 0 ? [avail[0].id] : [];

        return Prefs.splitList(raw).filter((id) => {
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
        if (!s || s.apps === "")
            return ;

        const list = root.chosen(ws).filter((x) => {
            return x !== id;
        });
        if (on)
            list.push(id);

        const order = (root.catalog[ws] || []).map((a) => {
            return a.id;
        });
        list.sort((a, b) => {
            return order.indexOf(a) - order.indexOf(b);
        });
        Prefs.set(s.apps, list.join(","));
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

    function termCommand(prog, cls) {
        const p = root.shQuote(prog);
        const c = root.shQuote(cls);
        return "if command -v kitty >/dev/null 2>&1; then exec kitty --class " + c + " -e " + p + "; " + "elif command -v foot >/dev/null 2>&1; then exec foot --app-id=" + c + " " + p + "; " + "elif command -v alacritty >/dev/null 2>&1; then exec alacritty --class " + c + " -e " + p + "; " + "elif command -v ghostty >/dev/null 2>&1; then exec ghostty --class=" + c + " -e " + p + "; fi";
    }

    // exec keeps the pid that launch rules go by; drops flags a field code left empty (--uri=)
    function launchCommand(app, entry) {
        if (app.term)
            return root.termCommand(app.term, app.class[0]);

        const argv = (entry.command || []).filter((a) => {
            return !/^--?[A-Za-z0-9_-]+=$/.test(a);
        });
        return argv.length > 0 ? "exec " + argv.map(root.shQuote).join(" ") : "";
    }

    function appLua(ws, id) {
        const app = root.appById(ws, id);
        const entry = app ? root.entryOf(app) : null;
        if (!entry)
            return "";

        const classes = app.class.slice();
        if (!app.term && entry.startupClass && !classes.some((c) => {
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
