import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// the displays page and what it reaches: per-output rules in lucid-monitors.lua
// for modules/monitors.lua, and which output the shell sits on
Singleton {
    id: root

    readonly property string dataPath: Quickshell.env("HOME") + "/.config/hypr/lucid-monitors.lua"
    readonly property string modulePath: Quickshell.env("HOME") + "/.config/hypr/modules/monitors.lua"

    // ---- live outputs -----------------------------------------------------
    property bool probed: false
    property var outputs: []

    // a description outlives the port it was plugged into, so it is the key
    function keyFor(name, description) {
        const d = String(description || "").trim();
        return d !== "" ? "desc:" + d : String(name);
    }

    function parseMode(s) {
        const m = String(s).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
        if (!m)
            return null;

        return {
            "w": parseInt(m[1], 10),
            "h": parseInt(m[2], 10),
            "hz": parseFloat(m[3]),
            "res": m[1] + "x" + m[2],
            "key": m[1] + "x" + m[2] + "@" + m[3]
        };
    }

    function output(key) {
        return root.outputs.find((o) => {
            return o.key === key;
        }) || null;
    }

    readonly property var keys: root.outputs.map((o) => {
        return o.key;
    })
    readonly property int liveCount: root.outputs.length
    // an output the page may not switch off, because it is the last one left
    readonly property int onCount: root.outputs.filter((o) => {
        return root.isOn(o.key);
    }).length

    function probe() {
        probeProc.running = false;
        probeProc.running = true;
    }

    Process {
        id: probeProc

        running: true
        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    for (const m of JSON.parse(this.text)) {
                        const modes = [];
                        for (const s of m.availableModes || []) {
                            const p = root.parseMode(s);
                            if (p && !modes.some((x) => {
                                return x.key === p.key;
                            }))
                                modes.push(p);

                        }
                        modes.sort((a, b) => {
                            return b.w * b.h - a.w * a.h || b.hz - a.hz;
                        });
                        list.push({
                            "name": String(m.name || ""),
                            "description": String(m.description || ""),
                            "key": root.keyFor(m.name, m.description),
                            "make": String(m.make || ""),
                            "model": String(m.model || ""),
                            "width": m.width || 0,
                            "height": m.height || 0,
                            "refresh": m.refreshRate || 0,
                            "x": m.x || 0,
                            "y": m.y || 0,
                            "scale": m.scale || 1,
                            "transform": m.transform || 0,
                            "vrr": m.vrr === true,
                            "disabled": m.disabled === true,
                            "focused": m.focused === true,
                            "mirrorOf": m.mirrorOf === "none" ? "" : String(m.mirrorOf || ""),
                            "physicalWidth": m.physicalWidth || 0,
                            "physicalHeight": m.physicalHeight || 0,
                            "modes": modes
                        });
                    }
                } catch (e) {
                    list = [];
                }
                list.sort((a, b) => {
                    return a.name < b.name ? -1 : 1;
                });
                root.outputs = list;
                root.probed = true;
            }
        }

    }

    // hyprland reports the new layout a beat after the event, so this settles
    Timer {
        id: probeDebounce

        interval: 350
        repeat: false
        onTriggered: root.probe()
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "monitoradded" || event.name === "monitoraddedv2" || event.name === "monitorremoved" || event.name === "monitorremovedv2" || event.name === "configreloaded")
                probeDebounce.restart();

        }

        target: Hyprland
    }

    // ---- what the page has set --------------------------------------------
    readonly property var setups: {
        let out = {};
        try {
            const parsed = JSON.parse(Prefs.monitorSetups || "{}");
            if (parsed && typeof parsed === "object")
                out = parsed;

        } catch (e) {
            out = {};
        }
        return out;
    }

    function setupOf(key) {
        return root.setups[key] || {};
    }

    function isTouched(key) {
        return Object.keys(root.setupOf(key)).length > 0;
    }

    // one write, through the alias, with only the fields that were set.
    // numbers are forced, because a QML signal typed string hands back "0"
    function write(key, patch) {
        const next = {};
        for (const k in root.setups) next[k] = root.setups[k];
        const cur = {};
        for (const k in root.setupOf(key)) cur[k] = root.setupOf(key)[k];
        for (const f in patch) {
            if (patch[f] === undefined || patch[f] === null)
                delete cur[f];
            else
                cur[f] = patch[f];
        }
        if (Object.keys(cur).length === 0)
            delete next[key];
        else
            next[key] = cur;

        Prefs.set("monitorSetups", JSON.stringify(next));
    }

    function clear(key) {
        const next = {};
        for (const k in root.setups) {
            if (k !== key)
                next[k] = root.setups[k];

        }
        Prefs.set("monitorSetups", JSON.stringify(next));
    }

    // ---- each setting, override first and what hyprland picked behind it ---
    function modeOf(key) {
        return root.setupOf(key).mode || "";
    }

    // the resolution and rate on screen right now, whoever chose them
    function liveModeKey(key) {
        const o = root.output(key);
        if (!o)
            return "";

        return o.width + "x" + o.height + "@" + o.refresh.toFixed(2);
    }

    function modeLabel(m) {
        return m.w + " × " + m.h + " at " + Math.round(m.hz) + " Hz";
    }

    function resLabel(res) {
        return String(res).replace("x", " × ");
    }

    function resolutionsOf(key) {
        const o = root.output(key);
        if (!o)
            return [];

        const out = [];
        for (const m of o.modes) {
            if (out.indexOf(m.res) === -1)
                out.push(m.res);

        }
        return out;
    }

    function ratesOf(key, res) {
        const o = root.output(key);
        if (!o)
            return [];

        return o.modes.filter((m) => {
            return m.res === res;
        }).map((m) => {
            return m.hz;
        });
    }

    // what the resolution and rate pickers should show as chosen
    function currentRes(key) {
        const mode = root.modeOf(key);
        if (mode !== "") {
            const p = root.parseMode(mode + "Hz");
            if (p)
                return p.res;

        }
        const o = root.output(key);
        if (!o)
            return "";

        // a rotated output reports its transformed size, which is no mode
        const all = root.resolutionsOf(key);
        const live = o.width + "x" + o.height;
        if (all.indexOf(live) !== -1 || all.length === 0)
            return live;

        const swapped = o.height + "x" + o.width;
        return all.indexOf(swapped) !== -1 ? swapped : all[0];
    }

    function currentRate(key) {
        const mode = root.modeOf(key);
        if (mode !== "") {
            const p = root.parseMode(mode + "Hz");
            if (p)
                return p.hz;

        }
        const o = root.output(key);
        return o ? o.refresh : 0;
    }

    // the closest rate this resolution actually offers, so switching resolution
    // cannot ask for a rate the panel does not have
    function nearestRate(key, res, want) {
        const rates = root.ratesOf(key, res);
        if (rates.length === 0)
            return 0;

        let best = rates[0];
        for (const r of rates) {
            if (Math.abs(r - want) < Math.abs(best - want))
                best = r;

        }
        return best;
    }

    // 60.049 on screen is mode 60.05, so the chip matches the nearest one
    function selectedRate(key) {
        return root.nearestRate(key, root.currentRes(key), root.currentRate(key));
    }

    function rateLabel(hz) {
        const r = Math.round(hz * 100) / 100;
        return (r % 1 === 0 ? String(r) : String(r).replace(/0+$/, "").replace(/\.$/, "")) + " Hz";
    }

    readonly property var scaleOptions: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    // scaling a 1080p panel past 200% leaves less room than any window wants,
    // so the page only offers what this panel can actually carry. whatever is
    // set now stays on the list either way
    function scalesFor(key) {
        const p = root.parseMode(root.currentRes(key) + "@60Hz");
        const cur = root.scaleOf(key);
        const out = root.scaleOptions.filter((v) => {
            return !p || p.w / v >= 960 || v === cur;
        });
        if (out.indexOf(cur) === -1)
            out.push(cur);

        return out.sort((a, b) => {
            return a - b;
        });
    }

    // the desk space an output gives at a scale, which is what you pick it for
    function logicalSize(key, scale) {
        const res = root.currentRes(key);
        const p = root.parseMode(res + "@60Hz");
        if (!p || scale <= 0)
            return "";

        let w = p.w;
        let h = p.h;
        if (root.isRotated(key)) {
            const t = w;
            w = h;
            h = t;
        }
        return Math.round(w / scale) + " × " + Math.round(h / scale);
    }

    // the physical panel, because a scale only means something against it
    function diagonalInches(key) {
        const o = root.output(key);
        if (!o || o.physicalWidth <= 0 || o.physicalHeight <= 0)
            return 0;

        return Math.sqrt(o.physicalWidth * o.physicalWidth + o.physicalHeight * o.physicalHeight) / 25.4;
    }

    function setResolution(key, res) {
        const hz = root.nearestRate(key, res, root.currentRate(key));
        if (hz <= 0)
            return ;

        root.write(key, {
            "mode": res + "@" + hz.toFixed(2)
        });
    }

    function setRate(key, hz) {
        root.write(key, {
            "mode": root.currentRes(key) + "@" + Number(hz).toFixed(2)
        });
    }

    function scaleOf(key) {
        const s = root.setupOf(key).scale;
        if (s !== undefined)
            return Number(s);

        const o = root.output(key);
        return o ? o.scale : 1;
    }

    function setScale(key, v) {
        root.write(key, {
            "scale": Math.round(v * 100) / 100
        });
    }

    // a scale that does not divide the panel evenly lands content on fractional
    // pixels, so the page marks the ones that do
    function isCleanScale(key, v) {
        const p = root.parseMode(root.currentRes(key) + "@60Hz");
        if (!p || v <= 0)
            return true;

        const w = p.w / v;
        const h = p.h / v;
        return Math.abs(w - Math.round(w)) < 0.01 && Math.abs(h - Math.round(h)) < 0.01;
    }

    function transformOf(key) {
        const t = root.setupOf(key).transform;
        if (t !== undefined)
            return Number(t);

        const o = root.output(key);
        return o ? o.transform : 0;
    }

    function setTransform(key, t) {
        root.write(key, {
            "transform": Number(t)
        });
    }

    readonly property var transforms: [
        { "key": 0, "label": "Landscape", "short": "0°" },
        { "key": 1, "label": "Portrait", "short": "90°" },
        { "key": 2, "label": "Landscape flipped", "short": "180°" },
        { "key": 3, "label": "Portrait flipped", "short": "270°" }
    ]

    function transformLabel(t) {
        const hit = root.transforms.find((x) => {
            return x.key === t;
        });
        return hit ? hit.label : "Flipped " + t;
    }

    // a rotated output swaps the side its size is measured on
    function isRotated(key) {
        const t = root.transformOf(key);
        return t === 1 || t === 3 || t === 5 || t === 7;
    }

    function vrrOf(key) {
        const v = root.setupOf(key).vrr;
        if (v !== undefined)
            return Number(v);

        const o = root.output(key);
        return o && o.vrr ? 1 : 0;
    }

    function setVrr(key, v) {
        root.write(key, {
            "vrr": Number(v)
        });
    }

    function isOn(key) {
        return root.setupOf(key).off !== true;
    }

    // the last output on cannot be switched off, or there is nothing to switch
    // it back on from
    function canTurnOff(key) {
        return root.isOn(key) ? root.onCount > 1 : true;
    }

    function setOn(key, on) {
        if (!on && !root.canTurnOff(key))
            return ;

        root.write(key, {
            "off": on ? undefined : true
        });
    }

    function mirrorOf(key) {
        const m = root.setupOf(key).mirror;
        if (m !== undefined)
            return m;

        const o = root.output(key);
        return o ? o.mirrorOf : "";
    }

    function setMirror(key, name) {
        root.write(key, {
            "mirror": name === "" ? undefined : name,
            "x": undefined,
            "y": undefined
        });
    }

    // ---- arrangement ------------------------------------------------------
    function isAuto(key) {
        const s = root.setupOf(key);
        return s.x === undefined || s.y === undefined;
    }

    function posOf(key) {
        const s = root.setupOf(key);
        if (s.x !== undefined && s.y !== undefined)
            return {
                "x": Number(s.x),
                "y": Number(s.y)
            };

        const o = root.output(key);
        return {
            "x": o ? o.x : 0,
            "y": o ? o.y : 0
        };
    }

    function setPos(key, x, y) {
        root.write(key, {
            "x": Math.round(x),
            "y": Math.round(y)
        });
    }

    // moving one output by hand leaves the others on "auto", which hyprland is
    // then free to place around it, so the first drag pins them all where they
    // already are
    function pinAll() {
        const next = {};
        for (const k in root.setups) next[k] = root.setups[k];
        let moved = false;
        for (const o of root.outputs) {
            if (!root.isOn(o.key) || !root.isAuto(o.key))
                continue;

            const cur = {};
            for (const f in root.setupOf(o.key)) cur[f] = root.setupOf(o.key)[f];
            cur.x = o.x;
            cur.y = o.y;
            next[o.key] = cur;
            moved = true;
        }
        if (moved)
            Prefs.set("monitorSetups", JSON.stringify(next));

    }

    function autoArrange() {
        const next = {};
        for (const k in root.setups) {
            const cur = {};
            for (const f in root.setups[k]) {
                if (f !== "x" && f !== "y")
                    cur[f] = root.setups[k][f];

            }
            if (Object.keys(cur).length > 0)
                next[k] = cur;

        }
        Prefs.set("monitorSetups", JSON.stringify(next));
    }

    // the size an output takes up in the layout, after scale and rotation
    function layoutSize(key) {
        const o = root.output(key);
        if (!o)
            return {
                "w": 0,
                "h": 0
            };

        const mode = root.modeOf(key);
        let w = o.width;
        let h = o.height;
        const p = mode !== "" ? root.parseMode(mode + "Hz") : null;
        if (p) {
            w = p.w;
            h = p.h;
        }
        const s = Math.max(0.1, root.scaleOf(key));
        if (root.isRotated(key)) {
            const t = w;
            w = h;
            h = t;
        }
        return {
            "w": Math.round(w / s),
            "h": Math.round(h / s)
        };
    }

    // ---- which output the shell sits on -----------------------------------
    // keyed like everything else here, so a display that comes back on another
    // port keeps the shell; older configs hold a bare name and still resolve.
    // read off hyprland's own monitor list, not the probe, so it answers on the
    // first frame instead of waiting for a process
    function screenFor(key) {
        if (key === "")
            return null;

        return Quickshell.screens.find((s) => {
            if (s.name === key)
                return true;

            const m = Hyprland.monitorFor(s);
            return m !== null && root.keyFor(s.name, m.description) === key;
        }) || null;
    }

    function keyForName(name) {
        const o = root.outputs.find((x) => {
            return x.name === name;
        });
        return o ? o.key : String(name || "");
    }

    function keyOf(screen) {
        return screen ? root.keyForName(screen.name) : "";
    }

    function nameOf(key) {
        const o = root.output(key);
        return o ? o.name : key;
    }

    readonly property var shellScreen: root.screenFor(Prefs.monitorShellScreen)
    // the display being worked on, for the surfaces that follow you instead
    readonly property var focusedScreen: {
        const m = Hyprland.focusedMonitor;
        if (!m)
            return null;

        return Quickshell.screens.find((s) => {
            return s.name === m.name;
        }) || null;
    }
    // what the rest of the shell means by the main display: the one the bar is
    // on, the first otherwise. widgets and their presets sit on this one
    readonly property var mainScreen: root.shellScreen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
    // the outputs a surface can actually be placed on, in the page's order
    readonly property var shellKeys: root.outputs.filter((o) => {
        return root.screenFor(o.key) !== null;
    }).map((o) => {
        return o.key;
    })
    // the stored value normalised, so a legacy name still lights its chip
    readonly property string shellKey: root.keyOf(root.shellScreen)
    // where the surfaces actually go. a pick that is unplugged falls back to a
    // live display, because a surface left pointing at a dead one is not drawn
    // at all, and nothing brings it back short of a reload
    function placementFor(key) {
        if (key === "")
            return null;

        return root.screenFor(key) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }

    readonly property var shellPlacement: root.placementFor(Prefs.monitorShellScreen)
    // the bar and dock may sit apart from the rest; empty follows the shell
    readonly property var barPlacement: root.placementFor(Prefs.monitorBarScreen) || root.shellPlacement
    readonly property var dockPlacement: root.placementFor(Prefs.monitorDockScreen) || root.shellPlacement

    // unplugging a display tears down the surfaces that were on it for good:
    // handing them a live screen is not enough, only a remap brings them back
    property bool surfacesUp: true
    readonly property int screenCount: Quickshell.screens.length

    onShellPlacementChanged: root.remapSurfaces()
    onBarPlacementChanged: root.remapSurfaces()
    onDockPlacementChanged: root.remapSurfaces()
    onScreenCountChanged: root.remapSurfaces()

    function remapSurfaces() {
        root.surfacesUp = false;
        remapSettle.restart();
    }

    Timer {
        id: remapSettle

        interval: 150
        onTriggered: root.surfacesUp = true
    }

    function setShellScreen(key) {
        Prefs.monitorShellScreen = (key === undefined || key === null) ? "" : String(key);
    }

    function setBarScreen(key) {
        Prefs.monitorBarScreen = (key === undefined || key === null) ? "" : String(key);
    }

    function setDockScreen(key) {
        Prefs.monitorDockScreen = (key === undefined || key === null) ? "" : String(key);
    }

    // the outputs left to right, which is the order a person describes them in
    readonly property var orderedKeys: root.shellKeys.slice().sort((a, b) => {
        const x = root.output(a);
        const y = root.output(b);
        return (x ? x.x : 0) - (y ? y.x : 0) || (x ? x.y : 0) - (y ? y.y : 0);
    })

    // "shell" | "bar" | "dock" -> the key it landed on, "" for automatic, or
    // null if the spec named nothing live
    function aimSurface(which, spec) {
        const from = which === "bar" ? root.keyOf(root.barPlacement) : (which === "dock" ? root.keyOf(root.dockPlacement) : root.shellKey);
        const key = root.resolveKey(spec, from);
        if (key === null)
            return null;

        if (which === "bar")
            root.setBarScreen(key);
        else if (which === "dock")
            root.setDockScreen(key);
        else
            root.setShellScreen(key);
        return key;
    }

    // the displays left to right, and what is sitting on each
    function rundown() {
        const keys = root.orderedKeys;
        if (keys.length === 0)
            return "no displays";

        const lines = keys.map((k) => {
            const o = root.output(k);
            const on = [];
            if (root.keyOf(root.shellPlacement) === k)
                on.push("shell");

            if (root.keyOf(root.barPlacement) === k)
                on.push("bar");

            if (root.keyOf(root.dockPlacement) === k)
                on.push("dock");

            return "  " + o.name + "  " + o.width + "x" + o.height + (o.description !== "" ? "  " + o.description : "") + (on.length > 0 ? "  <- " + on.join(", ") : "");
        });
        return lines.join("\n") + (Prefs.monitorShellScreen === "" ? "\n(shell display: automatic)" : "");
    }

    // the same, worded for a person: where it landed, or what went wrong
    function aimSurfaceLabel(which, spec) {
        const key = root.aimSurface(which, spec);
        if (key === null)
            return "no display called \"" + spec + "\", see: qs ipc call displays list";

        if (key !== "")
            return root.nameOf(key);

        return which === "shell" ? "automatic" : "follows the shell";
    }

    // one word for a display: an output name, its desc: key, where it sits in
    // the row, or where the shell is now. "" is the automatic setting
    function resolveKey(spec, from) {
        const want = String(spec === undefined || spec === null ? "" : spec).trim();
        if (want === "" || want === "auto" || want === "shell")
            return "";

        const keys = root.orderedKeys;
        if (keys.length === 0)
            return null;

        if (want === "left" || want === "middle" || want === "centre" || want === "center" || want === "right")
            return keys[want === "left" ? 0 : (want === "right" ? keys.length - 1 : Math.floor((keys.length - 1) / 2))];

        if (want === "here")
            return root.keyOf(root.focusedScreen);

        if (want === "next" || want === "prev") {
            const at = keys.indexOf(from !== "" ? from : root.keyOf(root.mainScreen));
            const step = want === "next" ? 1 : -1;
            return keys[((at < 0 ? 0 : at + step) % keys.length + keys.length) % keys.length];
        }
        if (root.output(want) !== null)
            return want;

        const byName = root.keyForName(want);
        return root.screenFor(byName) !== null ? byName : null;
    }

    // ---- workspaces ---------------------------------------------------------
    // shared: a workspace opens wherever you are. split: each one belongs to a
    // display, stored by key like the rest, so it follows the monitor between ports
    readonly property int workspaceCount: 10
    readonly property var workspacePlan: {
        let p = {};
        try {
            p = JSON.parse(Prefs.monitorWorkspaces || "{}") || {};
        } catch (e) {
            p = {};
        }
        return {
            "mode": p.mode === "split" ? "split" : "shared",
            "assign": (p.assign && typeof p.assign === "object") ? p.assign : {}
        };
    }
    readonly property bool workspacesSplit: root.workspacePlan.mode === "split"
    // split, but belonging to nothing plugged in, so hyprland places them itself
    readonly property int strayWorkspaces: {
        if (!root.workspacesSplit)
            return 0;

        let n = 0;
        for (let i = 1; i <= root.workspaceCount; i++) {
            const k = root.workspacePlan.assign[String(i)];
            if (!k || root.output(k) === null)
                n++;

        }
        return n;
    }

    function writeWorkspaces(mode, assign) {
        Prefs.set("monitorWorkspaces", JSON.stringify({
            "mode": mode,
            "assign": assign
        }));
    }

    function workspacesOf(key) {
        const out = [];
        for (let n = 1; n <= root.workspaceCount; n++) {
            if (root.workspacePlan.assign[String(n)] === key)
                out.push(n);

        }
        return out;
    }

    // the displays a workspace can live on: on, and not showing another one
    readonly property var workspaceKeys: root.orderedKeys.filter((k) => {
        return root.isOn(k) && root.mirrorOf(k) === "";
    })

    // runs of workspaces, from the leftmost display to the rightmost
    function evenSplit() {
        const keys = root.workspaceKeys;
        const assign = {};
        if (keys.length === 0)
            return assign;

        const per = Math.ceil(root.workspaceCount / keys.length);
        for (let n = 1; n <= root.workspaceCount; n++) assign[String(n)] = keys[Math.min(keys.length - 1, Math.floor((n - 1) / per))]
        return assign;
    }

    function setWorkspaceMode(mode) {
        const assign = root.workspacePlan.assign;
        root.writeWorkspaces(mode, (mode === "split" && Object.keys(assign).length === 0) ? root.evenSplit() : assign);
    }

    function assignWorkspace(n, key) {
        const assign = {};
        for (const k in root.workspacePlan.assign) assign[k] = root.workspacePlan.assign[k]
        assign[String(n)] = key;
        root.writeWorkspaces("split", assign);
    }

    function splitEvenly() {
        root.writeWorkspaces("split", root.evenSplit());
    }

    // ---- the rules file ---------------------------------------------------
    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
    }

    readonly property string rulesLua: {
        let out = "-- written by Lucid Settings > Displays, and rewritten on every change there\n";
        out += "return {\n    monitors = {\n";
        const names = Object.keys(root.setups).sort();
        for (const key of names) {
            const s = root.setups[key];
            const fields = ["output = " + root.luaStr(key)];
            if (s.off === true) {
                fields.push("disabled = true");
                out += "        { " + fields.join(", ") + " },\n";
                continue;
            }
            fields.push("mode = " + root.luaStr(s.mode !== undefined ? s.mode : "preferred"));
            if (s.mirror !== undefined && s.mirror !== "")
                fields.push("mirror = " + root.luaStr(s.mirror));
            else
                fields.push("position = " + root.luaStr(s.x !== undefined && s.y !== undefined ? s.x + "x" + s.y : "auto"));
            fields.push("scale = " + root.luaStr(s.scale !== undefined ? String(s.scale) : "1"));
            fields.push("transform = " + (s.transform !== undefined ? s.transform : 0));
            fields.push("vrr = " + (s.vrr !== undefined ? s.vrr : 0));
            out += "        { " + fields.join(", ") + " },\n";
        }
        out += "    },\n";
        out += root.workspacesLua;
        out += "}\n";
        return out;
    }

    // each display opens on its lowest workspace
    readonly property string workspacesLua: {
        if (!root.workspacesSplit)
            return "";

        const assign = root.workspacePlan.assign;
        const first = {};
        for (let n = 1; n <= root.workspaceCount; n++) {
            const k = assign[String(n)];
            if (k && first[k] === undefined)
                first[k] = n;

        }
        if (Object.keys(first).length === 0)
            return "";

        let out = "    workspaces = {\n";
        for (let n = 1; n <= root.workspaceCount; n++) {
            const k = assign[String(n)];
            if (!k)
                continue;

            out += "        { workspace = " + root.luaStr(String(n)) + ", monitor = " + root.luaStr(k) + (first[k] === n ? ", default = true" : "") + " },\n";
        }
        return out + "    },\n";
    }

    // hyprland keeps a workspace rule once it has one, so a change to these
    // takes a reload; the monitor rules alone are applied in place
    function workspacePart(text) {
        const at = String(text).indexOf("    workspaces = {");
        return at < 0 ? "" : String(text).slice(at);
    }

    function writeRules() {
        if (!Prefs.loaded || !dataFile.ready || root.rulesLua === dataFile.current)
            return ;

        dataFile.reloadAfter = root.workspacePart(dataFile.current) !== root.workspacePart(root.rulesLua);
        dataFile.current = root.rulesLua;
        dataFile.setText(root.rulesLua);
    }

    onRulesLuaChanged: rulesDebounce.restart()

    // a mode change takes the screen with it, so this waits out a drag
    Timer {
        id: rulesDebounce

        interval: 500
        repeat: false
        onTriggered: root.writeRules()
    }

    Connections {
        function onLoadedChanged() {
            rulesDebounce.restart();
        }

        target: Prefs
    }

    FileView {
        id: dataFile

        property bool ready: false
        property string current: ""
        property bool reloadAfter: false

        path: root.dataPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            dataFile.current = dataFile.text();
            dataFile.ready = true;
            rulesDebounce.restart();
        }
        onLoadFailed: {
            dataFile.current = "";
            dataFile.ready = true;
            rulesDebounce.restart();
        }
        // the rules live in hyprland, so it re-reads once the file is on disk
        onSaved: {
            if (dataFile.reloadAfter)
                Quickshell.execDetached(["hyprctl", "reload"]);
            else
                Quickshell.execDetached(["hyprctl", "eval", "if LucidMonitors then LucidMonitors.apply() end"]);
            probeDebounce.restart();
        }
        // a dropped write would otherwise stay "current" and never be retried
        onSaveFailed: dataFile.current = ""
    }

    // missing after --no-hypr, and the page says so
    FileView {
        id: moduleFile

        path: root.modulePath
        printErrors: false
        // an install from before this page existed has the old monitors.lua,
        // which reads no data file, so the marker is what counts
        onLoaded: {
            root.moduleInstalled = moduleFile.text().indexOf("LucidMonitors") !== -1;
            root.moduleProbed = true;
        }
        onLoadFailed: {
            root.moduleInstalled = false;
            root.moduleProbed = true;
        }
    }

    property bool moduleInstalled: false
    property bool moduleProbed: false

}
