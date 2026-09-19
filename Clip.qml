pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// clipboard history. cliphist owns the store; the shell owns the wl-paste
// watchers that feed it, so history records for as long as the shell runs.
// Quickshell.clipboardText is no use here: a layer surface never holds
// keyboard focus, so wayland hands it nothing.
Singleton {
    id: root

    property bool probed: false
    property bool available: false
    // newest first, as cliphist lists them
    property var entries: []
    // id -> decoded png url, filled lazily as image rows scroll into view
    property var thumbs: ({})
    property var thumbQueue: []
    property string thumbPending: ""
    property bool refreshQueued: false
    property var deleteQueue: []
    property int topId: 0
    // the selected entry at full size, for the launcher's preview pane
    property var fulls: ({})
    property string fullWanted: ""
    property string textId: ""
    property string textBody: ""
    property bool textReady: false
    property bool textTruncated: false
    property string textWanted: ""
    readonly property int textLimit: 16000

    readonly property int listLimit: 300
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-clip"
    readonly property bool watching: root.available && Prefs.clipboardEnabled

    function refresh() {
        if (!root.available)
            return;

        if (listProc.running) {
            root.refreshQueued = true;
            return;
        }
        listProc.running = true;
    }

    // "[[ binary data 516 KiB png 1614x854 ]]"; anything but an image comes
    // without the dimensions, and is no use to a thumbnail
    function binaryInfo(preview) {
        var m = preview.match(/^\[\[ binary data (\S+ \S+)(?: (\S+))?(?: (\d+)x(\d+))? \]\]$/);
        if (!m)
            return null;

        return {
            "size": m[1],
            "format": (m[2] || "").toLowerCase(),
            "width": m[3] ? parseInt(m[3], 10) : 0,
            "height": m[4] ? parseInt(m[4], 10) : 0
        };
    }

    // "PNG · 637×541 · 225 KiB"
    function imageMeta(info) {
        return info.format.toUpperCase() + " · " + info.width + "×" + info.height + " · " + info.size;
    }

    // text that is a colour, a link or an address is shown as one
    function textKind(preview) {
        var t = preview.trim();
        var hex = t.match(/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i);
        if (hex) {
            var h = hex[1];
            if (h.length === 3)
                h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];

            var rgb = h.substring(0, 6);
            var r = parseInt(rgb.substring(0, 2), 16), g = parseInt(rgb.substring(2, 4), 16), b = parseInt(rgb.substring(4, 6), 16);
            return {
                "kind": "color",
                // Qt reads 8 digits as #AARRGGBB, CSS writes #RRGGBBAA
                "color": "#" + (h.length === 8 ? h.substring(6) + rgb : rgb),
                "darkColor": 0.2126 * r + 0.7152 * g + 0.0722 * b < 140
            };
        }
        if (/^[a-z][a-z0-9+.-]*:\/\/\S+$/i.test(t))
            return {
                "kind": "url"
            };

        if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(t))
            return {
                "kind": "email"
            };

        return {
            "kind": "text"
        };
    }

    function parseList(text) {
        var out = [];
        var lines = text.split("\n");
        for (var i = 0; i < lines.length && out.length < root.listLimit; i++) {
            var line = lines[i];
            if (line === "")
                continue;

            var tab = line.indexOf("\t");
            if (tab <= 0)
                continue;

            var id = line.substring(0, tab);
            var preview = line.substring(tab + 1);
            var info = root.binaryInfo(preview);
            var isImage = info !== null && info.width > 0;
            var text = info === null ? root.textKind(preview) : null;
            out.push({
                "id": id,
                "preview": isImage ? "Image" : (info !== null ? "Binary data" : preview),
                "isImage": isImage,
                "meta": isImage ? root.imageMeta(info) : (info !== null ? (info.format !== "" ? info.format + " · " : "") + info.size : ""),
                "kind": isImage ? "image" : (info !== null ? "binary" : text.kind),
                "color": text && text.color ? text.color : "",
                "darkColor": !!(text && text.darkColor),
                "width": info !== null ? info.width : 0,
                "height": info !== null ? info.height : 0
            });
        }
        return out;
    }

    // cliphist ids only climb, so a drop means the db was reset under us and
    // every cached thumbnail now points at the wrong entry
    function adopt(rows) {
        var top = rows.length > 0 ? parseInt(rows[0].id, 10) || 0 : 0;
        if (top < root.topId)
            root.dropThumbs();

        root.topId = top;
        root.entries = rows;
    }

    function copy(id) {
        if (!root.available || id === "")
            return;

        // decode writes the original bytes, so wl-copy re-offers the real type
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", String(id)]);
    }

    function remove(id) {
        if (!root.available || id === "")
            return;

        var q = root.deleteQueue.slice();
        q.push(String(id));
        root.deleteQueue = q;
        root.pumpDeletes();
    }

    function pumpDeletes() {
        if (deleteProc.running || root.deleteQueue.length === 0)
            return;

        var q = root.deleteQueue.slice();
        var id = q.shift();
        root.deleteQueue = q;
        deleteProc.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "sh", id];
        deleteProc.running = true;
    }

    function wipe() {
        if (!root.available || wipeProc.running)
            return;

        wipeProc.running = true;
    }

    // delegates ask on completion rather than from a binding, so nothing
    // mutates state while the binding it feeds is being evaluated
    function requestThumb(id) {
        if (!root.available || id === "" || root.thumbs[id] !== undefined)
            return;

        if (root.thumbQueue.indexOf(id) !== -1 || root.thumbPending === id)
            return;

        var q = root.thumbQueue.slice();
        q.push(id);
        root.thumbQueue = q;
        root.pumpThumbs();
    }

    function pumpThumbs() {
        if (thumbProc.running || root.thumbQueue.length === 0)
            return;

        var q = root.thumbQueue.slice();
        var id = q.shift();
        root.thumbQueue = q;
        root.thumbPending = id;
        thumbProc.command = ["sh", "-c", "d=\"$1\"; i=\"$2\"; mkdir -p \"$d\" || exit 1; " + "cliphist decode \"$i\" > \"$d/$i.raw\" || { rm -f \"$d/$i.raw\"; exit 1; }; " + "magick \"$d/$i.raw\" -thumbnail 160x120 \"$d/$i.part\" 2>/dev/null || cp \"$d/$i.raw\" \"$d/$i.part\"; " + "rm -f \"$d/$i.raw\"; mv \"$d/$i.part\" \"$d/$i\"", "sh", root.thumbDir, String(id)];
        thumbProc.running = true;
    }

    function setThumb(id, url) {
        var t = {};
        for (var k in root.thumbs) t[k] = root.thumbs[k];
        t[id] = url;
        root.thumbs = t;
    }

    // a cached path whose file has since gone lets the next request re-decode
    function invalidateThumb(id) {
        if (id === "" || root.thumbs[id] === undefined)
            return;

        var t = {};
        for (var k in root.thumbs) {
            if (k !== id)
                t[k] = root.thumbs[k];

        }
        root.thumbs = t;
    }

    function dropThumbs() {
        root.thumbs = ({});
        root.thumbQueue = [];
        root.fulls = ({});
        Quickshell.execDetached(["sh", "-c", "rm -rf \"$1\"", "sh", root.thumbDir]);
    }

    function entry(id) {
        for (var i = 0; i < root.entries.length; i++) {
            if (root.entries[i].id === id)
                return root.entries[i];

        }
        return null;
    }

    // the original bytes, for the preview; one decode at a time, and only the
    // last entry asked for is worth decoding next
    function requestFull(id) {
        if (!root.available || id === "" || root.fulls[id] !== undefined)
            return;

        root.fullWanted = id;
        if (!fullProc.running)
            root.startFull();

    }

    function startFull() {
        var id = root.fullWanted;
        root.fullWanted = "";
        if (id === "" || root.fulls[id] !== undefined)
            return;

        fullProc.fullId = id;
        fullProc.command = ["sh", "-c", "d=\"$1\"; i=\"$2\"; mkdir -p \"$d\" && chmod 700 \"$d\" || exit 1; " + "cliphist decode \"$i\" > \"$d/full-$i.part\" && mv \"$d/full-$i.part\" \"$d/full-$i\" || { rm -f \"$d/full-$i.part\"; exit 1; }", "sh", root.thumbDir, String(id)];
        fullProc.running = true;
    }

    // the whole text, up to textLimit, for the preview
    function loadText(id) {
        if (!root.available || id === "")
            return;

        if (root.textId === id && (root.textReady || textProc.running))
            return;

        root.textWanted = id;
        if (!textProc.running)
            root.startText();

    }

    function startText() {
        var id = root.textWanted;
        root.textWanted = "";
        if (id === "")
            return;

        root.textId = id;
        root.textReady = false;
        textProc.command = ["sh", "-c", "cliphist decode \"$1\" | head -c " + (root.textLimit + 1), "sh", String(id)];
        textProc.running = true;
    }

    Process {
        id: fullProc

        property string fullId: ""

        onExited: (code) => {
            var t = {};
            for (var k in root.fulls) t[k] = root.fulls[k];
            t[fullProc.fullId] = code === 0 ? "file://" + root.thumbDir + "/full-" + fullProc.fullId : "";
            root.fulls = t;
            if (root.fullWanted !== "")
                root.startFull();

        }
    }

    Process {
        id: textProc

        // a newer request waiting means this text is already stale
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.textWanted !== "")
                    return;

                var body = this.text;
                root.textTruncated = body.length > root.textLimit;
                root.textBody = root.textTruncated ? body.substring(0, root.textLimit) : body;
                root.textReady = true;
            }
        }

        onExited: {
            if (root.textWanted !== "")
                root.startText();

        }
    }

    Process {
        id: probeProc

        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1"]
        onExited: (code) => {
            root.available = code === 0;
            root.probed = true;
            if (root.available) {
                root.dropThumbs();
                root.refresh();
            }

        }
    }

    // one watcher per family, the pair cliphist documents. a watcher the user
    // already runs is left alone: cliphist dedupes, so a double store is a
    // no-op rather than a duplicate row
    Process {
        id: textWatch

        running: root.watching
        command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"]
    }

    Process {
        id: imageWatch

        running: root.watching
        command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"]
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        onExited: {
            if (root.refreshQueued) {
                root.refreshQueued = false;
                listProc.running = true;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: root.adopt(root.parseList(this.text))
        }

    }

    Process {
        id: deleteProc

        onExited: {
            if (root.deleteQueue.length > 0)
                root.pumpDeletes();
            else
                root.refresh();
        }
    }

    Process {
        id: wipeProc

        command: ["cliphist", "wipe"]
        onExited: {
            root.dropThumbs();
            root.refresh();
        }
    }

    Process {
        id: thumbProc

        onExited: (code) => {
            root.setThumb(root.thumbPending, code === 0 ? "file://" + root.thumbDir + "/" + root.thumbPending : "");
            root.thumbPending = "";
            root.pumpThumbs();
        }
    }

}
