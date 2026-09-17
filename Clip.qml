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

    // "225 KiB png 637x541" -> "PNG · 637×541 · 225 KiB"
    function imageMeta(preview) {
        var m = preview.match(/binary data\s+(.+?)\s+(\w+)\s+(\d+)x(\d+)/);
        if (!m)
            return "Image";

        return m[2].toUpperCase() + " · " + m[3] + "×" + m[4] + " · " + m[1];
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
            var isImage = preview.indexOf("[[ binary data") === 0;
            out.push({
                "id": id,
                "preview": isImage ? "Image" : preview,
                "isImage": isImage,
                "meta": isImage ? root.imageMeta(preview) : ""
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
        Quickshell.execDetached(["sh", "-c", "rm -rf \"$1\"", "sh", root.thumbDir]);
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
