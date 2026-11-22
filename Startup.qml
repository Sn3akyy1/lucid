import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// Settings > Startup: apps opened at login and environment variables, kept in
// Prefs and rendered into lucid-startup.lua for modules/startup.lua, plus the
// XDG autostart entries, which startuptool.py reads and switches
Singleton {
    id: root

    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string dataPath: root.hyprDir + "/lucid-startup.lua"
    readonly property string modulePath: root.hyprDir + "/modules/startup.lua"
    readonly property string sessionPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-startup-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "none") + ".json"
    readonly property string helper: Qt.resolvedUrl("lucidprefs/startuptool.py").toString().replace("file://", "")
    property bool moduleInstalled: false
    property bool moduleProbed: false
    // what Settings' AppPicker is opened with for this page; no workspace has it
    readonly property string pickerKey: "@startup"

    // the session's own variables; the module refuses them too
    readonly property var protectedNames: ["WAYLAND_DISPLAY", "DISPLAY", "XDG_RUNTIME_DIR", "HYPRLAND_INSTANCE_SIGNATURE", "HYPRLAND_CMD", "HOME", "USER", "LOGNAME", "SHELL", "DBUS_SESSION_BUS_ADDRESS", "XDG_SESSION_ID", "XDG_SESSION_TYPE", "XDG_CURRENT_DESKTOP"]

    // [{ name, cmd, entry, on }]: entry is the desktop id an app was picked by
    readonly property var apps: root.parseList(Prefs.startupApps)
    // [{ name, value, on }]
    readonly property var vars: root.parseList(Prefs.startupEnv)
    // what this login started with, from modules/startup.lua
    property var session: null
    // what you added to modules/autostart.lua and modules/env.lua yourself, as
    // startuptool.py reads them; Lucid's own lines there are left out
    property var configApps: []
    property var configVars: []
    // what this machine has, for the suggestions
    property var facts: ({})
    property bool configProbed: false
    // the lines the page can take over: one plain call on one line
    readonly property var movable: root.configApps.concat(root.configVars).filter((l) => {
        return l.simple;
    })
    // XDG autostart, as startuptool.py lists it
    property var xdgEntries: []
    property string xdgTarget: ""
    property bool xdgProbed: false
    property bool xdgBusy: false

    function parseList(raw) {
        let list = [];
        try {
            list = JSON.parse(raw || "[]");
        } catch (e) {
            list = [];
        }
        return Array.isArray(list) ? list.filter((x) => {
            return x && typeof x === "object";
        }) : [];
    }

    // ---------------------------------------------------------------- apps

    function saveApps(list) {
        Prefs.startupApps = JSON.stringify(list.map((a) => {
            return {
                "name": String(a.name || ""),
                "cmd": String(a.cmd || ""),
                "entry": String(a.entry || ""),
                "on": a.on !== false
            };
        }));
    }

    // exec keeps the pid that launch rules go by; drops flags a field code left empty (--uri=)
    function entryCommand(e) {
        const argv = (e.command || []).filter((a) => {
            return !/^--?[A-Za-z0-9_-]+=$/.test(a);
        });
        if (argv.length === 0)
            return "";

        if (e.runInTerminal)
            return Specials.termCommand(argv, Specials.termClass(e.id));

        return "exec " + argv.map(Specials.shQuote).join(" ");
    }

    // everything installed that is not on the list yet, in the AppPicker's shape
    function installedApps() {
        const taken = {};
        for (const a of root.apps) {
            if (a.entry)
                taken[a.entry] = true;

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

    function addApp(entryId) {
        const e = DesktopEntries.byId(entryId);
        const cmd = e ? root.entryCommand(e) : "";
        if (cmd === "")
            return ;

        root.saveApps(root.apps.concat([{
            "name": e.name || entryId,
            "cmd": cmd,
            "entry": entryId,
            "on": true
        }]));
    }

    function addCommand(cmd) {
        const c = String(cmd).trim();
        if (c === "")
            return ;

        root.saveApps(root.apps.concat([{
            "name": c.split(/\s+/)[0].split("/").pop(),
            "cmd": c,
            "entry": "",
            "on": true
        }]));
    }

    function setApp(i, patch) {
        root.saveApps(root.apps.map((a, j) => {
            return j === i ? Object.assign({}, a, patch) : a;
        }));
    }

    function removeApp(i) {
        root.saveApps(root.apps.filter((a, j) => {
            return j !== i;
        }));
    }

    // through Hyprland, so it starts with the variables set here
    function runApp(i) {
        const a = root.apps[i];
        if (a && a.cmd)
            Quickshell.execDetached(["hyprctl", "eval", "hl.exec_cmd(" + root.luaStr(a.cmd) + ")"]);

    }

    function iconOf(a) {
        const e = a && a.entry ? DesktopEntries.byId(a.entry) : null;
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    // the program a command runs, as startuptool.py works it out:
    // "command -v nextcloud >/dev/null && exec nextcloud --background" -> nextcloud
    function programOf(cmd) {
        let words = String(cmd || "").replace(/['"]/g, " ").trim().split(/\s+/);
        const and = words.indexOf("&&");
        if (and !== -1 && and < words.length - 1)
            words = words.slice(and + 1);

        let i = 0;
        while (i < words.length && (["exec", "env", "command"].indexOf(words[i]) !== -1 || words[i].indexOf("=") !== -1 || /^-/.test(words[i])))
            i++;
        return i < words.length ? words[i].split("/").pop() : "";
    }

    // the command an app picked from the list was given, so a row can show
    // a command only when it is not just the app's own
    function ownCommand(a) {
        const e = a && a.entry ? DesktopEntries.byId(a.entry) : null;
        return e ? root.entryCommand(e) : "";
    }

    // ---------------------------------------------------------------- variables

    function saveVars(list) {
        Prefs.startupEnv = JSON.stringify(list.map((v) => {
            return {
                "name": String(v.name || ""),
                "value": String(v.value === undefined ? "" : v.value),
                "on": v.on !== false
            };
        }));
    }

    // why a name cannot be used, or "" when it can
    function nameProblem(name, index) {
        const n = String(name || "");
        if (n === "")
            return I18n.tr("Give it a name");

        if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(n))
            return I18n.tr("Letters, digits and _ only, not starting with a digit");

        if (root.protectedNames.indexOf(n) !== -1)
            return I18n.tr("%1 belongs to the session; changing it would cut apps off from it", n);

        for (let j = 0; j < root.vars.length; j++) {
            if (j !== index && root.vars[j].name === n)
                return I18n.tr("%1 is already on the list", n);

        }
        return "";
    }

    // variables that are no longer needed or do harm, checked against their
    // sources: a word of warning, never a refusal. "" when there is nothing to say
    function adviceFor(name, value) {
        const v = String(value || "").toLowerCase();
        const f = root.facts || {};
        const gpus = f.gpus || [];
        const alone = (list) => {
            return v.split(/[;,]/).map((x) => {
                return x.trim();
            }).filter((x) => {
                return x !== "";
            }).every((x) => {
                return list.indexOf(x) !== -1;
            });
        };
        switch (name) {
        case "ELECTRON_OZONE_PLATFORM_HINT":
            return I18n.tr("Does nothing now: Electron 38 removed it, and Electron apps run on Wayland by themselves.");
        case "MOZ_ENABLE_WAYLAND":
            return v === "0" ? I18n.tr("Sends Firefox back to XWayland, blurry on scaled screens and without touchpad gestures. Only worth it to get round a bug.") : I18n.tr("Not needed: Firefox runs on Wayland by itself since version 121.");
        case "NVD_BACKEND":
            return v === "egl" ? I18n.tr("The EGL backend of libva-nvidia-driver is broken on NVIDIA drivers 525 and later; direct, the default, is the one that works.") : (v === "direct" ? I18n.tr("Not needed: direct is already the default.") : "");
        case "STEAM_FORCE_DESKTOPUI_SCALING":
            return I18n.tr("Has stopped working for some people on Hyprland since 2025, and Steam follows the XWayland scale by itself now.");
        case "SDL_VIDEODRIVER":
            return v.indexOf("wayland") !== -1 && v.indexOf("x11") === -1 ? I18n.tr("Games built with an older SDL fail to start with it; Hyprland's wiki says to take it out, or set it to x11, if they do.") : "";
        case "GDK_BACKEND":
            if (v === "x11")
                return I18n.tr("Every GTK app goes through XWayland, blurry on scaled screens.");

            return alone(["wayland"]) ? I18n.tr("GTK apps without Wayland support stop opening, with nothing to fall back to. And GTK picks Wayland by itself in this session.") : I18n.tr("Not needed: GTK picks Wayland by itself in this session.");
        case "QT_QPA_PLATFORM":
            if (v === "xcb")
                return I18n.tr("Every Qt app goes through XWayland, blurry on scaled screens.");

            return alone(["wayland"]) ? I18n.tr("Apps whose Qt lacks the Wayland plugin, as AppImages and other bundled builds often do, stop starting. And Qt picks Wayland by itself in this session.") : I18n.tr("Not needed: Qt picks Wayland by itself in this session.");
        case "LIBVA_DRIVER_NAME":
            return v === "nvidia" && gpus.indexOf("nvidia") !== -1 && gpus.length > 1 ? I18n.tr("This machine has another graphics card that already decodes video. This moves decoding to the NVIDIA card, which keeps it awake and can draw more power than decoding on the processor.") : "";
        case "GDK_SCALE":
            return f.zeroScaling === false ? I18n.tr("Hyprland already scales apps running through XWayland (xwayland:force_zero_scaling is off), so GTK ones end up scaled twice.") : "";
        case "AQ_NO_ATOMIC":
            return I18n.tr("Hyprland's wiki: heavily not recommended.");
        }
        return "";
    }

    function addVar(name, value) {
        if (root.nameProblem(name, -1) !== "")
            return false;

        root.saveVars(root.vars.concat([{
            "name": name,
            "value": value,
            "on": true
        }]));
        return true;
    }

    function setVar(i, patch) {
        root.saveVars(root.vars.map((v, j) => {
            return j === i ? Object.assign({}, v, patch) : v;
        }));
    }

    function removeVar(i) {
        root.saveVars(root.vars.filter((v, j) => {
            return j !== i;
        }));
    }

    // the variables that go to Hyprland, name -> value
    readonly property var wantedVars: {
        const out = {};
        for (const v of root.vars) {
            if (v.on !== false && root.nameProblem(v.name, root.vars.indexOf(v)) === "")
                out[v.name] = v.value;

        }
        return out;
    }

    // "active": in force since login; "pending": set now, the dock and the
    // launcher pick it up at the next login. with no record of this login the
    // module came after it, so nothing of ours was set then
    function varState(v) {
        if (v.on === false)
            return "";

        const env = root.session && root.session.env ? root.session.env : {};
        return env[v.name] === v.value ? "active" : "pending";
    }

    // set at login and since taken off the list or switched off
    readonly property var lingering: {
        if (!root.session || !root.session.env)
            return [];

        return Object.keys(root.session.env).filter((n) => {
            return root.wantedVars[n] === undefined;
        });
    }

    // variables worth setting on this machine, offered only when Lucid finds
    // what each fixes. what Hyprland's wiki lists for every machine
    // (GDK_BACKEND, QT_QPA_PLATFORM, SDL_VIDEODRIVER...) is left out: the
    // toolkits pick Wayland on their own now, and SDL on Wayland breaks games
    readonly property var suggestions: {
        const f = root.facts || {};
        const gpus = f.gpus || [];
        const out = [];
        if (f.java)
            out.push({
                "name": "_JAVA_AWT_WM_NONREPARENTING",
                "value": "1",
                "why": I18n.tr("Java apps otherwise open as a grey box or close their menus at once: Java knows a fixed list of window managers, and Hyprland is not on it.")
            });

        if (gpus.length === 1 && gpus[0] === "nvidia" && f.libvaNvidia)
            out.push({
                "name": "LIBVA_DRIVER_NAME",
                "value": "nvidia",
                "why": I18n.tr("Browsers and video players decode video on the NVIDIA card, through libva-nvidia-driver. It can draw more power than decoding on the processor.")
            });

        if (f.zeroScaling && f.maxScale >= 2)
            out.push({
                "name": "GDK_SCALE",
                "value": String(Math.floor(f.maxScale)),
                "why": I18n.tr("Hyprland leaves apps that run through XWayland unscaled (xwayland:force_zero_scaling), so GTK ones come out tiny; this has them scale themselves. Wayland apps ignore it.")
            });

        const taken = {};
        for (const v of root.vars)
            taken[v.name] = true;
        for (const v of root.configVars)
            taken[v.name] = true;
        return out.filter((x) => {
            return !taken[x.name];
        });
    }

    function refreshConfig() {
        if (!configProc.running)
            configProc.running = true;

    }

    // lines from the two files: moved ones join the lists here, the rest are
    // only commented out (an app two things start, kept to one)
    function take(lines, moved) {
        if (takeProc.running || lines.length === 0)
            return ;

        takeProc.command = ["python3", root.helper, "take", JSON.stringify(lines.map((l) => {
            return {
                "file": l.file,
                "line": l.line,
                "text": l.text,
                "moved": moved
            };
        }))];
        takeProc.moved = moved;
        takeProc.lines = lines;
        takeProc.running = true;
    }

    function adopt(lines) {
        let apps = root.apps.slice();
        let vars = root.vars.slice();
        for (const l of lines) {
            if (l.file === "autostart") {
                const e = l.program ? DesktopEntries.heuristicLookup(l.program) : null;
                apps.push({
                    "name": e && e.name ? e.name : (l.program || l.cmd),
                    "cmd": l.cmd,
                    "entry": e ? e.id : "",
                    "on": true
                });
            } else if (!vars.some((v) => {
                return v.name === l.name;
            })) {
                vars.push({
                    "name": l.name,
                    "value": l.value,
                    "on": true
                });
            }
        }
        root.saveApps(apps);
        root.saveVars(vars);
    }

    // ---------------------------------------------------------------- xdg autostart

    // everything the page shows from outside, read again each time it opens
    function refresh() {
        if (!listProc.running)
            listProc.running = true;

        sessionFile.reload();
        root.refreshConfig();
    }

    function setXdg(id, on) {
        root.xdgBusy = true;
        setProc.command = ["python3", root.helper, "set", id, on ? "on" : "off"];
        setProc.running = true;
    }

    // the XDG entries the session will start: on, meant for this desktop, installed
    readonly property var xdgRunning: root.xdgEntries.filter((e) => {
        return e.enabled && e.applies && e.installed;
    })
    // the session starts them itself (uwsm and the like) rather than through
    // the switch here
    readonly property bool xdgBySession: root.xdgTarget === "active" && !(root.session && root.session.xdg)
    readonly property bool xdgStarts: root.xdgBySession || Prefs.startupXdg

    // an app this list or modules/autostart.lua starts that an XDG entry starts too
    function xdgTwin(program) {
        if (!root.xdgStarts || program === "")
            return null;

        for (const e of root.xdgRunning) {
            if (e.program === program)
                return e;

        }
        return null;
    }

    // ---------------------------------------------------------------- the data file

    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r") + "\"";
    }

    readonly property string rendered: {
        let out = "-- written by Lucid Settings > Startup, and rewritten on every change there\n";
        out += "return {\n";
        out += "    xdg = " + (Prefs.startupXdg ? "true" : "false") + ",\n";
        out += "    env = {\n";
        for (const n in root.wantedVars)
            out += "        { name = " + root.luaStr(n) + ", value = " + root.luaStr(root.wantedVars[n]) + " },\n";
        out += "    },\n";
        out += "    apps = {\n";
        for (const a of root.apps) {
            if (a.on !== false && a.cmd)
                out += "        { name = " + root.luaStr(a.name || a.cmd) + ", cmd = " + root.luaStr(a.cmd) + " },\n";

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

        interval: 600
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
        onSaved: Quickshell.execDetached(["hyprctl", "eval", "if LucidStartup then LucidStartup.apply() end"])
    }

    FileView {
        path: root.modulePath
        printErrors: false
        onLoaded: {
            root.moduleInstalled = true;
            root.moduleProbed = true;
        }
        onLoadFailed: {
            root.moduleInstalled = false;
            root.moduleProbed = true;
        }
    }

    FileView {
        id: sessionFile

        path: root.sessionPath
        printErrors: false
        onLoaded: {
            try {
                root.session = JSON.parse(sessionFile.text());
            } catch (e) {
                root.session = null;
            }
        }
        onLoadFailed: root.session = null
    }

    FileView {
        id: autostartFile

        path: root.hyprDir + "/modules/autostart.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: autostartFile.reload()
        onLoaded: root.refreshConfig()
        onLoadFailed: root.refreshConfig()
    }

    FileView {
        id: envFile

        path: root.hyprDir + "/modules/env.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: envFile.reload()
        onLoaded: root.refreshConfig()
        onLoadFailed: root.refreshConfig()
    }

    Process {
        id: listProc

        command: ["python3", root.helper, "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    d = {};
                }
                root.xdgEntries = Array.isArray(d.entries) ? d.entries : [];
                root.xdgTarget = d.target || "";
                root.xdgProbed = true;
            }
        }

    }

    Process {
        id: configProc

        command: ["python3", root.helper, "config"]

        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    d = {};
                }
                const mine = (l) => {
                    return !l.lucid;
                };
                root.configApps = (d.apps || []).filter(mine);
                root.configVars = (d.env || []).filter(mine);
                root.facts = d.facts || {};
                root.configProbed = true;
            }
        }

    }

    Process {
        id: takeProc

        property bool moved: true
        property var lines: []

        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try {
                    d = JSON.parse(this.text.trim() || "{}");
                } catch (e) {
                    d = {};
                }
                const done = d.done || [];
                if (takeProc.moved)
                    root.adopt(takeProc.lines.filter((l) => {
                    return done.some((x) => {
                        return x.file === l.file && x.line === l.line;
                    });
                }));

                root.refreshConfig();
            }
        }

    }

    Process {
        id: setProc

        onExited: {
            root.xdgBusy = false;
            root.refresh();
        }
    }

}
