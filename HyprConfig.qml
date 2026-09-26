import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// the Hyprland options Settings > Windows and Input change: kept in Prefs.hyprOptions,
// rendered into lucid-settings.lua for modules/settings.lua, and read back
// from Hyprland so a page shows what is really in force
Singleton {
    id: root

    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"
    readonly property string dataPath: root.hyprDir + "/lucid-settings.lua"
    readonly property string modulePath: root.hyprDir + "/modules/settings.lua"
    readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-settings-status.json"
    property bool moduleInstalled: false
    property bool moduleProbed: false

    // every option a page shows, read back in one hyprctl call
    readonly property var keys: ["general.gaps_in", "general.gaps_out", "general.border_size", "general.col.active_border", "general.col.inactive_border", "decoration.rounding", "decoration.rounding_power", "decoration.shadow.enabled", "decoration.shadow.range", "decoration.shadow.render_power", "decoration.dim_inactive", "decoration.dim_strength", "general.layout", "dwindle.split_width_multiplier", "dwindle.force_split", "dwindle.default_split_ratio", "dwindle.preserve_split", "master.orientation", "master.mfact", "master.new_status", "master.new_on_top", "scrolling.column_width", "scrolling.fullscreen_on_one_column", "input.follow_mouse", "misc.focus_on_activate", "cursor.no_warps", "cursor.warp_on_change_workspace", "general.resize_on_border", "general.extend_border_grab_area", "general.snap.enabled", "general.snap.window_gap", "general.snap.monitor_gap", "cursor.hide_on_key_press", "cursor.inactive_timeout", "animations.enabled", "input.kb_layout", "input.kb_variant", "input.kb_options", "input.repeat_rate", "input.repeat_delay", "input.numlock_by_default", "input.sensitivity", "input.accel_profile", "input.natural_scroll", "input.scroll_factor", "input.left_handed", "input.touchpad.tap-to-click", "input.touchpad.natural_scroll", "input.touchpad.scroll_factor", "input.touchpad.disable_while_typing", "input.touchpad.clickfinger_behavior", "input.touchpad.tap-and-drag", "input.touchpad.middle_button_emulation"]
    // not Hyprland options but choices Lucid turns into some
    readonly property var borderModes: [{
        "key": "none",
        "label": "None"
    }, {
        "key": "accent",
        "label": "Accent"
    }, {
        "key": "gradient",
        "label": "Gradient"
    }]
    // Hyprland as it is now, key -> value
    property var live: ({})
    // written by modules/settings.lua: which options your config overrides
    property var status: ({})
    // what Settings set, key -> value
    readonly property var mine: {
        let m = {};
        try {
            m = JSON.parse(Prefs.hyprOptions || "{}");
        } catch (e) {
            m = {};
        }
        return m && typeof m === "object" && !Array.isArray(m) ? m : {};
    }
    // what hyprland.lua requires after modules.settings, [{ name, text }], for
    // naming the file that overrides an option
    property var laterFiles: []

    // options whose value Lucid works out, such as border colours from the palette
    function derived() {
        const out = {};
        for (const k of ["lucid.border", "lucid.inactive_border"]) {
            const t = root.targetOf(k, root.mine[k]);
            if (t.value !== undefined)
                out[t.option] = t.value;

        }
        return out;
    }

    // the option a key stands for and the value it gives it; a choice such as
    // lucid.border becomes a border colour worked out from the palette
    function targetOf(key, v) {
        if (key === "lucid.border") {
            let c;
            if (v === "none")
                c = "rgba(00000000)";
            else if (v === "accent")
                c = root.rgba(Theme.cPrimary, 1);
            else if (v === "gradient")
                c = {
                "colors": [root.rgba(Theme.cPrimary, 1), root.rgba(Theme.cTertiary, 1), root.rgba(Theme.cSecondary, 1)],
                "angle": 45
            };
            return {
                "option": "general.col.active_border",
                "value": c
            };
        }
        if (key === "lucid.inactive_border")
            return {
            "option": "general.col.inactive_border",
            "value": v === "none" ? "rgba(00000000)" : (v === "faint" ? root.rgba(Theme.cOutlineVariant, 1) : undefined)
        };

        if (key.indexOf("lucid.") === 0)
            return {
            "option": "",
            "value": undefined
        };

        return {
            "option": key,
            "value": v
        };
    }

    // a value the way modules/settings.lua reports your config's own:
    // colours as "aarrggbb,…@angle"
    function plainOf(option, v) {
        if (option.indexOf(".col.") === -1)
            return v;

        const argb = (c) => {
            const m = /^rgba\(([0-9a-f]{6})([0-9a-f]{2})\)$/i.exec(String(c).trim());
            return m ? (m[2] + m[1]).toLowerCase() : String(c).toLowerCase().replace(/^0x/, "");
        };
        if (v && typeof v === "object" && Array.isArray(v.colors))
            return v.colors.map(argb).join(",") + "@" + Math.round(Number(v.angle) || 0);

        return argb(v) + "@0";
    }

    // whether a value is the one your config gives the option anyway
    function sameAsBase(option, v) {
        const b = (root.status.base || {})[option];
        if (option === "" || v === undefined || b === undefined || b === null || root.isOverridden(option))
            return false;

        const p = root.plainOf(option, v);
        if (typeof p === "number" && typeof b === "number")
            return Math.abs(p - b) < 0.0001;

        return p === b;
    }

    // what goes to Hyprland: the options set as they are, the choices worked out
    readonly property var wanted: {
        const out = {};
        for (const k in root.mine) {
            if (k.indexOf("lucid.") !== 0)
                out[k] = root.mine[k];

        }
        return Object.assign(out, root.derived());
    }

    // a border colour as a list of colours: "rgba(rrggbbaa)", { colors, angle } or Hyprland's "aarrggbb … 45deg"
    function coloursOf(v) {
        const out = [];
        const add = (s) => {
            let m = /^rgba?\(([0-9a-f]{6})([0-9a-f]{2})?\)$/i.exec(String(s).trim());
            if (m) {
                out.push(Qt.color("#" + (m[2] || "ff") + m[1]));
                return ;
            }
            m = /^(?:0x)?([0-9a-f]{8})$/i.exec(String(s).trim());
            if (m)
                out.push(Qt.color("#" + m[1]));

        };
        if (v && typeof v === "object" && Array.isArray(v.colors))
            v.colors.forEach(add);
        else if (typeof v === "string")
            v.split(/\s+/).forEach(add);
        return out.length > 0 ? out : [Qt.color("transparent")];
    }

    function rgba(c, alpha) {
        const hex = (x) => {
            return ("0" + Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16)).slice(-2);
        };
        return "rgba(" + hex(c.r) + hex(c.g) + hex(c.b) + hex(alpha) + ")";
    }

    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\"";
    }

    function luaValue(v) {
        if (typeof v === "boolean")
            return v ? "true" : "false";

        if (typeof v === "number")
            return isFinite(v) ? String(Math.round(v * 10000) / 10000) : "0";

        if (Array.isArray(v))
            return "{ " + v.map(root.luaValue).join(", ") + " }";

        if (v && typeof v === "object")
            return "{ " + Object.keys(v).sort().map((k) => {
            return k + " = " + root.luaValue(v[k]);
        }).join(", ") + " }";

        return root.luaStr(v);
    }

    readonly property string rendered: {
        const w = root.wanted;
        let out = "-- written by Lucid Settings > Windows and Input, and rewritten on every change there\n";
        out += "return {\n";
        // rules rather than options: a window alone on its workspace goes edge to edge
        if (root.mine["lucid.solo"] === true)
            out += "    solo = true,\n";

        out += "    options = {\n";
        for (const k of Object.keys(w).sort())
            out += "        [" + root.luaStr(k) + "] = " + root.luaValue(w[k]) + ",\n";
        out += "    },\n}\n";
        return out;
    }

    function keysIn(text) {
        const out = [];
        const re = /^\s*\["([^"]+)"\]\s*=/gm;
        let m;
        while ((m = re.exec(text || "")) !== null) out.push(m[1])
        return out;
    }

    // --- what pages ask

    function isMine(key) {
        if (root.mine[key] !== undefined)
            return true;

        return root.derived()[key] !== undefined;
    }

    function isOverridden(key) {
        return (root.status.overridden || []).indexOf(key) !== -1;
    }

    function failedText(key) {
        const f = (root.status.failed || {})[key];
        return f ? "Hyprland did not take this: " + f + "." : "";
    }

    // the whole words an option's name is made of, bar its section
    function words(key) {
        return key.split(".").slice(1).join(".").split(/[.:]/);
    }

    function overrideText(key) {
        const names = [];
        for (const f of root.laterFiles) {
            const text = f.text;
            if (text === "" || names.indexOf(f.name) !== -1)
                continue;

            const found = root.words(key).every((w) => {
                return new RegExp("(^|[^A-Za-z0-9_])" + w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "([^A-Za-z0-9_]|$)").test(text);
            });
            if (found)
                names.push(f.name === "hyprland-gui.lua" ? "HyprMod (hyprland-gui.lua)" : f.name);

        }
        const who = names.length > 0 ? names.join(" and ") : "Something in your Hyprland config after Lucid";
        return who + " sets this too, and your own config wins over Settings. Take it out there to change it here.";
    }

    // a value from Settings until the file is on disk, Hyprland's after
    function value(key) {
        const d = root.wanted[key];
        if (d !== undefined && !root.isOverridden(key))
            return d;

        return root.live[key];
    }

    // gaps come back as "t r b l"; the first one stands for all
    function num(key, fallback) {
        const v = root.value(key);
        if (typeof v === "number")
            return v;

        if (typeof v === "boolean")
            return v ? 1 : 0;

        const n = parseFloat(String(v === undefined ? "" : v).trim().split(/\s+/)[0]);
        return isNaN(n) ? fallback : n;
    }

    function bool(key, fallback) {
        const v = root.value(key);
        if (typeof v === "boolean")
            return v;

        if (typeof v === "number")
            return v !== 0;

        return fallback;
    }

    function choice(key) {
        return root.mine[key] !== undefined ? root.mine[key] : "";
    }

    // putting an option back to what your config gives it hands it back
    function set(key, v) {
        const t = root.targetOf(key, v);
        if (root.sameAsBase(t.option, t.value)) {
            root.resetKeys([key]);
            return ;
        }
        const m = Object.assign({}, root.mine);
        m[key] = v;
        Prefs.hyprOptions = JSON.stringify(m);
    }

    // several at once, so the file is written once and they land together;
    // all of them back at your config's values hands them all back
    function setMany(values) {
        const keys = Object.keys(values);
        if (keys.every((k) => {
            return root.sameAsBase(k, values[k]);
        })) {
            root.resetKeys(keys);
            return ;
        }
        Prefs.hyprOptions = JSON.stringify(Object.assign({}, root.mine, values));
    }

    // --- keyboard

    signal layoutPickerRequested(var taken)

    // kb_layout and kb_variant as pairs; the variants line up with the layouts
    function layoutList() {
        const layouts = String(root.value("input.kb_layout") || "us").split(",");
        const variants = String(root.value("input.kb_variant") || "").split(",");
        const out = [];
        for (let i = 0; i < layouts.length; i++) {
            const l = layouts[i].trim();
            if (l !== "")
                out.push({
                "layout": l,
                "variant": (variants[i] || "").trim()
            });

        }
        return out;
    }

    function setLayouts(list) {
        if (list.length === 0)
            return ;

        root.setMany({
            "input.kb_layout": list.map((e) => {
                return e.layout;
            }).join(","),
            "input.kb_variant": list.some((e) => {
                return e.variant !== "";
            }) ? list.map((e) => {
                return e.variant;
            }).join(",") : ""
        });
    }

    function layoutId(e) {
        return e.variant !== "" ? e.layout + "(" + e.variant + ")" : e.layout;
    }

    function kbOptions() {
        return String(root.value("input.kb_options") || "").split(",").map((o) => {
            return o.trim();
        }).filter((o) => {
            return o !== "";
        });
    }

    // the option of a group in force, "" for none; caps covers ctrl:nocaps too
    function inGroup(group, o) {
        if (group === "caps")
            return o.indexOf("caps:") === 0 || o === "ctrl:nocaps" || o === "ctrl:swapcaps";

        return o.indexOf(group + ":") === 0;
    }

    function kbOption(group) {
        return root.kbOptions().find((o) => {
            return root.inGroup(group, o);
        }) || "";
    }

    // swaps one group's option and keeps every other option as it was
    function setKbOption(group, option) {
        const rest = root.kbOptions().filter((o) => {
            return !root.inGroup(group, o);
        });
        if (option !== "")
            rest.push(option);

        root.set("input.kb_options", rest.join(","));
    }

    // options whose own value is known go back to it live; the rest take a reload
    property var restoreQueue: []

    function resetKeys(list) {
        const m = Object.assign({}, root.mine);
        const queue = root.restoreQueue.slice();
        for (const k of list) {
            delete m[k];
            // a colour set by a choice goes with the choice, and the other way round
            if (k === "general.col.active_border")
                delete m["lucid.border"];

            if (k === "general.col.inactive_border")
                delete m["lucid.inactive_border"];

            const option = root.targetOf(k, "").option || k;
            if (option !== "" && (root.status.base || {})[option] !== undefined && queue.indexOf(option) === -1)
                queue.push(option);

        }
        root.restoreQueue = queue;
        Prefs.hyprOptions = JSON.stringify(m);
    }

    // what you set by hand to its config value, or what the config has since
    // come to set the same, stops being Settings'
    function prune() {
        const same = Object.keys(root.mine).filter((k) => {
            const t = root.targetOf(k, root.mine[k]);
            return root.sameAsBase(t.option, t.value);
        });
        if (same.length > 0)
            root.resetKeys(same);

    }

    // --- Hyprland's side

    function normalize(o) {
        for (const t of ["int", "float", "bool", "str", "css", "gradient", "vec2", "custom"]) {
            if (o[t] === undefined)
                continue;

            if (t === "css") {
                const parts = String(o.css).trim().split(/\s+/).map(Number);
                return parts.every((p) => {
                    return p === parts[0];
                }) ? parts[0] : String(o.css);
            }
            // an empty string nobody set reads back as a marker
            if (t === "str" && o.str === "[[EMPTY]]")
                return "";

            return o[t];
        }
        return undefined;
    }

    function refresh() {
        if (readProc.running)
            refreshAgain.restart();
        else
            readProc.running = true;
    }

    function write() {
        if (!Prefs.loaded || !dataFile.ready || root.rendered === dataFile.current)
            return ;

        // Hyprland has no way to unset an option: one whose own value is known
        // is put back to it, anything else dropped takes a reload
        const after = root.keysIn(root.rendered);
        const gone = root.keysIn(dataFile.current).filter((k) => {
            return after.indexOf(k) === -1;
        });
        dataFile.restoring = gone.filter((k) => {
            return root.restoreQueue.indexOf(k) !== -1;
        });
        dataFile.dropped = gone.length > dataFile.restoring.length;
        root.restoreQueue = [];
        dataFile.current = root.rendered;
        dataFile.setText(root.rendered);
    }

    onRenderedChanged: writeDebounce.restart()

    Timer {
        id: writeDebounce

        interval: 150
        onTriggered: root.write()
    }

    Timer {
        id: refreshAgain

        interval: 250
        onTriggered: root.refresh()
    }

    Connections {
        function onLoadedChanged() {
            writeDebounce.restart();
        }

        target: Prefs
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                refreshAgain.restart();

        }

        target: Hyprland
    }

    Process {
        id: readProc

        command: ["hyprctl", "-j", "--batch", root.keys.map((k) => {
            return "getoption " + k;
        }).join("; ")]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const chunk of this.text.match(/\{[^{}]*\}/g) || []) {
                    try {
                        const o = JSON.parse(chunk);
                        const v = root.normalize(o);
                        if (o.option && v !== undefined)
                            out[String(o.option).replace(/:/g, ".")] = v;

                    } catch (e) {
                    }
                }
                root.live = out;
            }
        }

    }

    FileView {
        id: dataFile

        property bool ready: false
        property string current: ""
        property bool dropped: false
        property var restoring: []

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
        onSaved: {
            if (dataFile.dropped)
                Quickshell.execDetached(["hyprctl", "reload"]);
            else
                Quickshell.execDetached(["hyprctl", "eval", "if LucidSettings then " + (dataFile.restoring.length > 0 ? "LucidSettings.restore({ " + dataFile.restoring.map(root.luaStr).join(", ") + " }) " : "") + "LucidSettings.apply(true) end"]);
            dataFile.dropped = false;
            dataFile.restoring = [];
            refreshAgain.restart();
        }
    }

    FileView {
        path: root.statusPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.status = JSON.parse(text()) || {};
            } catch (e) {
                root.status = {};
            }
        }
        onLoadFailed: root.status = {}
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

    // the modules hyprland.lua requires after this one, as files
    function laterPaths(text) {
        const lines = String(text || "").split("\n");
        const at = lines.findIndex((l) => {
            return /^\s*require\s*\(?\s*["']modules\.settings["']/.test(l);
        });
        if (at === -1)
            return [];

        const out = [];
        for (const l of lines.slice(at + 1)) {
            const m = /^\s*(?:pcall\s*\(\s*)?require\s*[(,]?\s*["']([^"']+)["']/.exec(l);
            if (m)
                out.push(root.hyprDir + "/" + m[1].replace(/\./g, "/") + ".lua");

        }
        return out;
    }

    function readLater() {
        const paths = root.laterPaths(hyprlandLua.loaded ? hyprlandLua.text() : "");
        if (paths.length === 0) {
            root.laterFiles = [];
            return ;
        }
        laterProc.command = ["bash", "-c", "for p; do [ -f \"$p\" ] || continue; printf '\\036%s\\037' \"${p##*/}\"; cat \"$p\"; done", "later"].concat(paths);
        laterProc.running = true;
    }

    FileView {
        id: hyprlandLua

        path: root.hyprDir + "/hyprland.lua"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.readLater()
    }

    Process {
        id: laterProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.laterFiles = this.text.split("\u001e").filter((c) => {
                    return c.indexOf("\u001f") !== -1;
                }).map((c) => {
                    const i = c.indexOf("\u001f");
                    return {
                        "name": c.slice(0, i),
                        "text": c.slice(i + 1)
                    };
                });
            }
        }

    }

    onStatusChanged: {
        if ((root.status.overridden || []).length > 0)
            root.readLater();

        pruneLater.restart();
    }

    // after the status settles, not in the middle of a write
    Timer {
        id: pruneLater

        interval: 400
        onTriggered: root.prune()
    }

}
