import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton

// the Hyprland keybinds, as ~/.config/lucid/keybinds.json holds them. hypr's
// modules/binds.lua binds from that same file, so saving here and reloading
// Hyprland is the whole round trip. Settings -> Keybinds edits through this and
// the SUPER+/ sheet reads it
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/lucid/keybinds.json"
    readonly property string statusPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-keybinds-status.json"
    // defined by binds.lua: no binds but SUPER+Escape, so a combo being recorded
    // reaches the settings window instead of doing whatever it is bound to
    readonly property string captureSubmap: "lucid_capture"
    readonly property var fieldOrder: ["id", "keys", "desc", "category", "type", "cmd", "lua", "each", "opts", "enabled"]

    property var binds: []
    property bool loaded: false
    property bool missing: false
    // set while the file on disk does not parse. nothing is saved until it does,
    // or a hand edit in progress would be replaced by the last list that parsed
    property string parseError: ""
    // what binds.lua reported on Hyprland's last config load
    property var status: ({})
    // binds Hyprland holds outside submaps, wherever they came from
    property int hyprCount: -1
    property bool capturing: false

    readonly property bool emergency: root.status.source === "emergency"
    readonly property int appliedCount: root.status.applied !== undefined ? root.status.applied : -1
    // binds from hypr-user.lua or another module, which this list cannot touch
    readonly property int extraCount: (root.hyprCount >= 0 && root.appliedCount >= 0 && !root.emergency) ? Math.max(0, root.hyprCount - root.appliedCount) : 0

    readonly property var categories: {
        var seen = [];
        for (var i = 0; i < root.binds.length; i++) {
            var c = root.categoryOf(root.binds[i]);
            if (seen.indexOf(c) === -1)
                seen.push(c);

        }
        return seen;
    }

    // id -> why it did not bind, from the last load
    readonly property var failed: {
        var out = {};
        var list = root.status.failed || [];
        for (var i = 0; i < list.length; i++) {
            if (out[list[i].id] === undefined)
                out[list[i].id] = list[i].keys + ": " + list[i].error;

        }
        return out;
    }

    // id -> ids of the other enabled binds sharing a combo with it
    readonly property var conflicts: {
        var owners = {};
        for (var i = 0; i < root.binds.length; i++) {
            var b = root.binds[i];
            if (b.enabled === false)
                continue;

            var combos = root.combosOf(b);
            for (var j = 0; j < combos.length; j++) {
                if (!owners[combos[j]])
                    owners[combos[j]] = [];

                if (owners[combos[j]].indexOf(b.id) === -1)
                    owners[combos[j]].push(b.id);

            }
        }
        var out = {};
        for (var k in owners) {
            var ids = owners[k];
            if (ids.length < 2)
                continue;

            for (var m = 0; m < ids.length; m++) {
                var others = out[ids[m]] || [];
                for (var n = 0; n < ids.length; n++) {
                    if (n !== m && others.indexOf(ids[n]) === -1)
                        others.push(ids[n]);

                }
                out[ids[m]] = others;
            }
        }
        return out;
    }

    // whatever opens the sheet, pretty-printed, for the hints that mention it
    readonly property string sheetKeys: {
        for (var i = 0; i < root.binds.length; i++) {
            var b = root.binds[i];
            if (b.enabled !== false && String(b.cmd || "").indexOf("ipc call keybinds") !== -1)
                return root.tokens(b.keys).join(" + ");

        }
        return "";
    }

    readonly property var capNames: ({
        "super": "Super",
        "shift": "Shift",
        "ctrl": "Ctrl",
        "control": "Ctrl",
        "alt": "Alt",
        "left": "←",
        "right": "→",
        "up": "↑",
        "down": "↓",
        "return": "Enter",
        "kp_enter": "Enter",
        "escape": "Esc",
        "space": "Space",
        "tab": "Tab",
        "backspace": "Backspace",
        "delete": "Del",
        "insert": "Ins",
        "prior": "PgUp",
        "page_up": "PgUp",
        "next": "PgDn",
        "page_down": "PgDn",
        "print": "PrtSc",
        "minus": "-",
        "equal": "=",
        "plus": "+",
        "comma": ",",
        "period": ".",
        "slash": "/",
        "backslash": "\\",
        "semicolon": ";",
        "apostrophe": "'",
        "grave": "`",
        "bracketleft": "[",
        "bracketright": "]",
        "less": "<",
        "mouse:272": "Left click",
        "mouse:273": "Right click",
        "mouse:274": "Middle click",
        "mouse_down": "Scroll ↓",
        "mouse_up": "Scroll ↑",
        "mouse_left": "Scroll ←",
        "mouse_right": "Scroll →",
        "xf86audioraisevolume": "Vol +",
        "xf86audiolowervolume": "Vol −",
        "xf86audiomute": "Mute",
        "xf86audiomicmute": "Mic mute",
        "xf86monbrightnessup": "Bright +",
        "xf86monbrightnessdown": "Bright −",
        "xf86audioplay": "Play",
        "xf86audiopause": "Pause",
        "xf86audionext": "Next",
        "xf86audioprev": "Prev",
        "xf86audiostop": "Stop",
        "{key}": "1 – 0"
    })

    // xkb keycodes (what Qt reports as the native scan code on Wayland) to the
    // names Hyprland binds by. by position, so Shift+1 is still "1" and not "!"
    readonly property var scanNames: ({
        "9": "Escape",
        "10": "1",
        "11": "2",
        "12": "3",
        "13": "4",
        "14": "5",
        "15": "6",
        "16": "7",
        "17": "8",
        "18": "9",
        "19": "0",
        "20": "minus",
        "21": "equal",
        "22": "BackSpace",
        "23": "Tab",
        "34": "bracketleft",
        "35": "bracketright",
        "36": "Return",
        "47": "semicolon",
        "48": "apostrophe",
        "49": "grave",
        "51": "backslash",
        "59": "comma",
        "60": "period",
        "61": "slash",
        "65": "space",
        "67": "F1",
        "68": "F2",
        "69": "F3",
        "70": "F4",
        "71": "F5",
        "72": "F6",
        "73": "F7",
        "74": "F8",
        "75": "F9",
        "76": "F10",
        "94": "less",
        "95": "F11",
        "96": "F12",
        "104": "KP_Enter",
        "107": "Print",
        "110": "Home",
        "111": "up",
        "112": "Page_Up",
        "113": "left",
        "114": "right",
        "115": "End",
        "116": "down",
        "117": "Page_Down",
        "118": "Insert",
        "119": "Delete",
        "127": "Pause"
    })
    readonly property var modifierScans: [37, 50, 62, 64, 66, 105, 108, 133, 134]

    signal editRequested(string id)
    // a bind that is not saved yet, for the editor to open filled in
    signal newRequested(var preset)
    signal sheetRequested()

    function categoryOf(b) {
        return b && b.category ? b.category : "Other";
    }

    function find(id) {
        for (var i = 0; i < root.binds.length; i++) {
            if (root.binds[i].id === id)
                return root.binds[i];

        }
        return null;
    }

    function indexOf(id) {
        for (var i = 0; i < root.binds.length; i++) {
            if (root.binds[i].id === id)
                return i;

        }
        return -1;
    }

    // "ctrl + SUPER + t" and "SUPER+CTRL+T" are the same bind
    function normCombo(keys) {
        var parts = String(keys || "").split("+").map((p) => {
            return p.trim();
        }).filter((p) => {
            return p !== "";
        });
        var mods = [];
        var key = "";
        for (var i = 0; i < parts.length; i++) {
            var u = parts[i].toUpperCase();
            if (u === "CONTROL")
                u = "CTRL";

            if (u === "WIN" || u === "LOGO" || u === "MOD4")
                u = "SUPER";

            if (["SUPER", "CTRL", "ALT", "SHIFT"].indexOf(u) !== -1) {
                if (mods.indexOf(u) === -1)
                    mods.push(u);

            } else {
                key = u;
            }
        }
        mods.sort();
        return mods.concat([key]).join("+");
    }

    function combosOf(b) {
        var keys = String(b.keys || "");
        if (b.each !== "workspace")
            return [root.normCombo(keys)];

        var out = [];
        for (var i = 1; i <= 10; i++) out.push(root.normCombo(keys.replace(/\{key\}/g, String(i % 10))))
        return out;
    }

    function tokens(keys) {
        var parts = String(keys || "").split("+").map((p) => {
            return p.trim();
        }).filter((p) => {
            return p !== "";
        });
        // "SUPER + Super_L" is a tap of Super on its own
        if (parts.length === 2 && parts[0].toUpperCase() === "SUPER" && /^super_[lr]$/i.test(parts[1]))
            return ["Super"];

        return parts.map((p) => {
            var n = root.capNames[p.toLowerCase()];
            if (n !== undefined)
                return n;

            if (/^xf86/i.test(p))
                return p.substring(4);

            return p.length === 1 ? p.toUpperCase() : p;
        });
    }

    function summary(b) {
        if (!b)
            return "";

        if (b.type === "lua") {
            var code = String(b.lua || "").trim();
            var nl = code.indexOf("\n");
            return nl === -1 ? code : code.substring(0, nl) + " …";
        }
        return String(b.cmd || "");
    }

    function displayDesc(b) {
        if (!b)
            return "";

        return String(b.desc || root.summary(b)).replace(/\{n\}/g, "1–10");
    }

    // every word has to turn up somewhere: description, category, keys or action
    function matches(b, q) {
        if (q === "")
            return true;

        var hay = [b.desc, b.category, b.keys, root.tokens(b.keys).join(" "), b.cmd, b.lua].join("\n").toLowerCase();
        return q.split(/\s+/).every((w) => {
            return hay.indexOf(w) !== -1;
        });
    }

    // known fields in a fixed order and empty ones left out, so the file diffs
    // cleanly; anything else a hand edit added rides along at the end
    function clean(b) {
        var out = {};
        var fields = root.fieldOrder.concat(Object.keys(b).filter((k) => {
            return root.fieldOrder.indexOf(k) === -1;
        }));
        for (var i = 0; i < fields.length; i++) {
            var k = fields[i];
            var v = b[k];
            if (v === undefined || v === null || v === "")
                continue;

            if (k === "enabled" && v === true)
                continue;

            if (k === "cmd" && b.type === "lua")
                continue;

            if (k === "lua" && b.type !== "lua")
                continue;

            if (k === "opts") {
                var o = {};
                for (var ok in v) {
                    if (v[ok] !== false && v[ok] !== undefined && v[ok] !== null && v[ok] !== "")
                        o[ok] = v[ok];

                }
                if (Object.keys(o).length === 0)
                    continue;

                v = o;
            }
            out[k] = v;
        }
        return out;
    }

    // one entry per line, the same shape the shipped file has
    function serialize(list) {
        var lines = list.map((b) => {
            return "    " + JSON.stringify(root.clean(b), null, 1).replace(/\n */g, " ");
        });
        return "{\n  \"version\": 1,\n  \"binds\": [\n" + lines.join(",\n") + "\n  ]\n}\n";
    }

    function parse(text) {
        root.loaded = true;
        root.missing = false;
        try {
            var data = JSON.parse(text);
            var list = Array.isArray(data) ? data : (data && Array.isArray(data.binds) ? data.binds : null);
            if (!list)
                throw new Error("there is no \"binds\" list");

            list = list.filter((b) => {
                return b && typeof b === "object";
            });
            for (var i = 0; i < list.length; i++) {
                if (!list[i].id)
                    list[i].id = "entry-" + (i + 1);

            }
            root.binds = list;
            root.parseError = "";
        } catch (e) {
            // the last good list stays on screen rather than an empty page
            root.parseError = String(e.message || e);
        }
    }

    function save(list) {
        if (root.parseError !== "")
            return false;

        root.binds = list;
        root.missing = false;
        file.setText(root.serialize(list));
        reloadDelay.restart();
        return true;
    }

    function newId(base) {
        var slug = String(base || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").substring(0, 32) || "bind";
        var id = slug;
        for (var n = 2; root.indexOf(id) !== -1; n++) id = slug + "-" + n
        return id;
    }

    // returns the id it was saved under, or "" when saving is blocked
    function upsert(entry) {
        var e = root.clean(entry);
        var list = root.binds.slice();
        var at = e.id ? root.indexOf(e.id) : -1;
        if (at !== -1) {
            list[at] = e;
        } else {
            if (!e.id)
                e.id = root.newId(e.desc || e.keys);

            // after the last of its category, so the file stays grouped
            var last = -1;
            for (var i = 0; i < list.length; i++) {
                if (root.categoryOf(list[i]) === root.categoryOf(e))
                    last = i;

            }
            if (last === -1)
                list.push(e);
            else
                list.splice(last + 1, 0, e);
        }
        return root.save(list) ? e.id : "";
    }

    function remove(id) {
        return root.save(root.binds.filter((b) => {
            return b.id !== id;
        }));
    }

    function setEnabled(id, on) {
        return root.save(root.binds.map((b) => {
            if (b.id !== id)
                return b;

            var copy = Object.assign({}, b);
            copy.enabled = on;
            return copy;
        }));
    }

    function reloadHyprland() {
        reloadDelay.restart();
    }

    function refreshCount() {
        countProc.running = false;
        countProc.running = true;
    }

    // json opens in the browser by default here, so reach for an editor
    function openFile() {
        Quickshell.execDetached(["sh", "-c", "if command -v codium >/dev/null; then exec codium \"$1\"; elif command -v code >/dev/null; then exec code \"$1\"; else exec kitty -e \"${EDITOR:-nvim}\" \"$1\"; fi", "sh", root.path]);
    }

    function startCapture() {
        Hyprland.dispatch("hl.dsp.submap(\"" + root.captureSubmap + "\")");
        root.capturing = true;
        captureTimeout.restart();
    }

    function stopCapture() {
        captureTimeout.stop();
        if (!root.capturing)
            return ;

        root.capturing = false;
        Hyprland.dispatch("hl.dsp.submap(\"reset\")");
    }

    function modsOf(event) {
        var m = [];
        if (event.modifiers & Qt.MetaModifier)
            m.push("SUPER");

        if (event.modifiers & Qt.ControlModifier)
            m.push("CTRL");

        if (event.modifiers & Qt.AltModifier)
            m.push("ALT");

        if (event.modifiers & Qt.ShiftModifier)
            m.push("SHIFT");

        return m;
    }

    function keyName(event) {
        var k = event.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k);

        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String.fromCharCode(k);

        var n = root.scanNames[String(event.nativeScanCode)];
        if (n !== undefined)
            return n;

        switch (k) {
        case Qt.Key_VolumeUp:
            return "XF86AudioRaiseVolume";
        case Qt.Key_VolumeDown:
            return "XF86AudioLowerVolume";
        case Qt.Key_VolumeMute:
            return "XF86AudioMute";
        case Qt.Key_MicMute:
            return "XF86AudioMicMute";
        case Qt.Key_MonBrightnessUp:
            return "XF86MonBrightnessUp";
        case Qt.Key_MonBrightnessDown:
            return "XF86MonBrightnessDown";
        case Qt.Key_MediaPlay:
        case Qt.Key_MediaTogglePlayPause:
            return "XF86AudioPlay";
        case Qt.Key_MediaPause:
            return "XF86AudioPause";
        case Qt.Key_MediaNext:
            return "XF86AudioNext";
        case Qt.Key_MediaPrevious:
            return "XF86AudioPrev";
        case Qt.Key_MediaStop:
            return "XF86AudioStop";
        case Qt.Key_Calculator:
            return "XF86Calculator";
        }
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24)
            return "F" + (k - Qt.Key_F1 + 1);

        return event.nativeScanCode > 0 ? "code:" + event.nativeScanCode : "";
    }

    // "" while only modifiers are down
    function comboFromEvent(event) {
        var k = event.key;
        if (k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_AltGr || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_CapsLock)
            return "";

        if (root.modifierScans.indexOf(event.nativeScanCode) !== -1)
            return "";

        var key = root.keyName(event);
        return key === "" ? "" : root.modsOf(event).concat([key]).join(" + ");
    }

    Component.onCompleted: root.refreshCount()

    FileView {
        id: file

        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: {
            root.loaded = true;
            root.missing = true;
            root.binds = [];
        }
    }

    FileView {
        id: statusFile

        path: root.statusPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var s = JSON.parse(text());
                if (s && typeof s === "object")
                    root.status = s;

            } catch (e) {
                // caught mid-write; the finished file fires another change
            }
        }
    }

    Timer {
        id: reloadDelay

        interval: 150
        onTriggered: {
            reloadProc.running = false;
            reloadProc.running = true;
        }
    }

    Process {
        id: reloadProc

        command: ["hyprctl", "reload"]
        onExited: countDelay.restart()
    }

    // the status file may not have existed when the watch was set up
    Timer {
        id: countDelay

        interval: 400
        onTriggered: {
            statusFile.reload();
            root.refreshCount();
        }
    }

    Process {
        id: countProc

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hyprCount = JSON.parse(text).filter((b) => {
                        return !b.submap;
                    }).length;
                } catch (e) {
                    root.hyprCount = -1;
                }
            }
        }

    }

    // a recording left running would keep every bind switched off
    Timer {
        id: captureTimeout

        interval: 15000
        onTriggered: root.stopCapture()
    }

    // SUPER+Escape inside the capture submap leaves it without telling us
    Connections {
        function onRawEvent(event) {
            if (root.capturing && event.name === "submap" && event.data !== root.captureSubmap) {
                captureTimeout.stop();
                root.capturing = false;
            }
        }

        target: Hyprland
    }

}
