import QtQuick
import Quickshell
import Quickshell.Io
import qs

// lens's process-wide side: the picture daemon, lens's own settings file and the
// open windows. lumen's settings are read, never written: a folder goes by in
// the order lumen shows it
Scope {
    id: app

    property string home: Quickshell.env("HOME")
    property bool ready: false
    // what this machine can do: {wallpaper, ocr, phone, lumen, pictures, decodable}
    property var caps: ({})
    property int _nextId: 1
    property var _pending: ({})
    property var _queue: []
    property int _nextWin: 1
    property var focusedWindow: null
    property alias prefs: state
    property bool stateReady: false
    property var _whenReady: []
    // lumen's sorts: its default, and each folder's own by path
    property var lumen: ({
        "sortKey": "name",
        "sortDesc": false,
        "folderSorts": {},
        "hidden": false
    })
    property int lumenRev: 0
    // what a window is handed: inside its own scope `app` would be itself
    readonly property var lensApp: app

    signal folderEvent(var ev)
    signal thumbEvent(string path, string thumb)
    // how far a long job (a video being cut) has got, 0 to 1
    signal progressEvent(string job, real t)

    function call(op, args, cb) {
        var id = app._nextId++;
        var req = Object.assign({}, args || {});
        req.op = op;
        req.id = id;
        if (cb)
            app._pending[id] = cb;

        var line = JSON.stringify(req) + "\n";
        if (daemon.running && app.ready)
            daemon.write(line);
        else
            app._queue.push(line);
        return id;
    }

    function receive(line) {
        if (!line)
            return ;

        var m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            console.warn("lens: bad line from the daemon");
            return ;
        }
        if (m.id !== undefined && m.ev === undefined) {
            var cb = app._pending[m.id];
            if (cb) {
                delete app._pending[m.id];
                cb(m);
            } else if (m.ok === false) {
                console.warn("lens: " + (m.error || "request failed"));
            }
            return ;
        }
        switch (m.ev) {
        case "ready":
            app.ready = true;
            var q = app._queue;
            app._queue = [];
            for (var i = 0; i < q.length; i++) daemon.write(q[i])
            break;
        case "folder":
            app.folderEvent(m);
            break;
        case "thumb":
            app.thumbEvent(m.path, m.thumb || "");
            break;
        case "progress":
            app.progressEvent(m.job || "", m.t || 0);
            break;
        }
    }

    // ---- paths

    function normalise(p) {
        if (!p)
            return "";

        if (p.indexOf("file://") === 0)
            p = decodeURIComponent(p.slice(7));

        if (p === "~" || p.indexOf("~/") === 0)
            p = app.home + p.slice(1);

        if (p.length > 1 && p.charAt(p.length - 1) === "/")
            p = p.slice(0, -1);

        return p;
    }

    function parentOf(p) {
        var i = p.lastIndexOf("/");
        return i <= 0 ? "/" : p.slice(0, i);
    }

    function nameOf(p) {
        return p.slice(p.lastIndexOf("/") + 1);
    }

    function extOf(p) {
        var n = app.nameOf(p), i = n.lastIndexOf(".");
        return i > 0 ? n.slice(i + 1).toLowerCase() : "";
    }

    function uriOf(path) {
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    function titleOf(p) {
        if (!p)
            return "this folder";

        return p === app.home ? "Home" : app.nameOf(p);
    }

    // where a folder sits, said short: ~/Pictures/trips
    function placeOf(p) {
        if (p === app.home)
            return "Home";

        return p.indexOf(app.home + "/") === 0 ? "~" + p.slice(app.home.length) : p;
    }

    // qt draws these itself; the decodable ones go through the daemon into a png
    function qtShows(p) {
        return (app.caps.qt || ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"]).indexOf(app.extOf(p)) >= 0;
    }

    function animatedKind(p) {
        var e = app.extOf(p);
        return e === "gif" || e === "webp";
    }

    function vectorKind(p) {
        var e = app.extOf(p);
        return e === "svg" || e === "svgz";
    }

    // videos play; these three ask what the daemon said this machine can do with one
    function videoKind(p) {
        return (app.caps.videos || []).indexOf(app.extOf(p)) >= 0;
    }

    // a live wallpaper, to the wallpaper script
    function liveKind(p) {
        return (app.caps.live || []).indexOf(app.extOf(p)) >= 0;
    }

    // turned by a note in the file, nothing encoded again
    function turnableKind(p) {
        return (app.caps.turnable || []).indexOf(app.extOf(p)) >= 0;
    }

    // ---- sorting, the way lumen sorts the folder (lucidlumen/Tab.qml)

    function sortOf(path) {
        var s = (app.lumen.folderSorts || {})[path] || {
            "key": app.lumen.sortKey || "name",
            "desc": app.lumen.sortDesc === true
        };
        return {
            "key": s.key === "deleted" ? "modified" : s.key,
            "desc": s.desc === true
        };
    }

    // a name in runs of digits and of everything else. split once per name: a sort
    // compares every name a dozen times over, and a folder can hold thousands
    function naturalKey(name) {
        return name.toLowerCase().match(/\d+|\D+/g) || [];
    }

    function natural(ka, kb) {
        var n = Math.min(ka.length, kb.length);
        for (var i = 0; i < n; i++) {
            var x = ka[i], y = kb[i];
            if (x === y)
                continue;

            var cx = x.charCodeAt(0), cy = y.charCodeAt(0);
            if (cx >= 48 && cx <= 57 && cy >= 48 && cy <= 57) {
                var d = Number(x) - Number(y);
                if (d !== 0)
                    return d;

                if (x.length !== y.length)
                    return x.length - y.length;

            } else {
                return x < y ? -1 : 1;
            }
        }
        return (ka.length > n ? 1 : 0) - (kb.length > n ? 1 : 0);
    }

    function sorted(list, folder) {
        var s = app.sortOf(folder), key = s.key, desc = s.desc, nat = app.natural;
        var keys = {};
        for (var i = 0; i < list.length; i++) keys[list[i].name] = app.naturalKey(list[i].name)
        var out = list.slice();
        out.sort(function(a, b) {
            var r = 0;
            if (key === "size")
                r = a.size - b.size;
            else if (key === "modified")
                r = a.mtime - b.mtime;
            else if (key === "type")
                r = (a.desc || "").localeCompare(b.desc || "");
            if (r !== 0)
                return desc ? -r : r;

            // a tie goes by name, a to z, whichever way the rest runs
            r = nat(keys[a.name], keys[b.name]);
            return key === "name" && desc ? -r : r;
        });
        return out;
    }

    function sortLabel(folder) {
        var s = app.sortOf(folder);
        var names = {
            "name": "Name",
            "size": "Size",
            "modified": "Date modified",
            "type": "Type"
        };
        return (names[s.key] || "Name") + (s.desc ? ", descending" : "");
    }

    // ---- sizes and dates, as people read them

    function sizeText(b) {
        if (b < 1000)
            return b + " B";

        var u = ["kB", "MB", "GB", "TB"], i = -1;
        do {
            b /= 1000;
            i++;
        } while (b >= 1000 && i < u.length - 1)
        return (b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    function dateText(secs) {
        if (!secs)
            return "";

        var d = new Date(secs * 1000), now = new Date();
        var day = 86400000;
        var start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        var time = d.toLocaleTimeString(Qt.locale(), "hh:mm");
        if (d.getTime() >= start)
            return "Today " + time;

        if (d.getTime() >= start - day)
            return "Yesterday " + time;

        if (d.getFullYear() === now.getFullYear())
            return d.toLocaleDateString(Qt.locale(), "d MMM") + ", " + time;

        return d.toLocaleDateString(Qt.locale(), "d MMM yyyy") + ", " + time;
    }

    // the same inside a sentence: today at 19:32, on 28 Oct
    function whenText(secs) {
        if (!secs)
            return "";

        var d = new Date(secs * 1000), now = new Date();
        var start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        var time = d.toLocaleTimeString(Qt.locale(), "hh:mm");
        if (d.getTime() >= start)
            return "today at " + time;

        if (d.getTime() >= start - 86400000)
            return "yesterday at " + time;

        return "on " + d.toLocaleDateString(Qt.locale(), d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
    }

    // a time into a video: 0:07, 12:40, 1:02:03
    function timeText(ms) {
        var t = Math.max(0, Math.floor((ms || 0) / 1000));
        var h = Math.floor(t / 3600), m = Math.floor(t / 60) % 60, s = t % 60;
        var ss = (s < 10 ? "0" : "") + s;
        return h > 0 ? h + ":" + (m < 10 ? "0" : "") + m + ":" + ss : m + ":" + ss;
    }

    // exif keeps the camera's wall-clock time with no zone: 2026-07-14T18:22:05
    function takenText(s) {
        var m = /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):?(\d*)/.exec(s || "");
        if (!m)
            return s || "";

        var d = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0));
        return app.dateText(d.getTime() / 1000);
    }

    // ---- windows

    function whenReady(fn) {
        if (app.stateReady)
            fn();
        else
            app._whenReady = app._whenReady.concat([fn]);
    }

    onStateReadyChanged: {
        var later = app._whenReady;
        app._whenReady = [];
        for (var i = 0; i < later.length; i++) later[i]()
    }

    // files one a line: one opens its folder, several are a set of their own
    function openPaths(text) {
        if (!app.stateReady) {
            app.whenReady(function() {
                app.openPaths(text);
            });
            return ;
        }
        idle.stop();
        var list = (text || "").split("\n").filter(function(s) {
            return s.trim() !== "";
        }).map(app.normalise);
        windows.append({
            "wid": "w" + (app._nextWin++),
            "files": list.join("\n")
        });
    }

    function closeWindow(wid) {
        for (var i = 0; i < windows.count; i++) {
            if (windows.get(i).wid === wid) {
                windows.remove(i);
                break;
            }
        }
        if (windows.count === 0)
            idle.restart();

    }

    // with no window left it lingers, so the next picture opens at once, then
    // goes and gives its memory back
    function quitWhenIdle() {
        if (windows.count === 0)
            Qt.quit();

    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", app.home + "/.local/state/lucid"]);
        app.call("hello", {
        }, function(r) {
            app.caps = r;
        });
        app.openPaths(Quickshell.env("LENS_OPEN") || "");
    }

    ListModel {
        id: windows
    }

    Timer {
        id: idle

        interval: Quickshell.env("LENS_EXIT_ON_CLOSE") === "1" ? 0 : 300000
        onTriggered: app.quitWhenIdle()
    }

    Instantiator {
        model: windows

        delegate: LensWindow {
            required property string wid
            required property string files

            app: lensApp
            winId: wid
            startFiles: files
        }

    }

    Process {
        id: daemon

        command: ["python3", Qt.resolvedUrl("lensd.py").toString().replace("file://", "")]
        running: true
        stdinEnabled: true
        onExited: (code) => {
            app.ready = false;
            console.warn("lens: the picture daemon stopped (" + code + "), starting it again");
            restart.start();
        }

        stdout: SplitParser {
            onRead: (data) => {
                return app.receive(data);
            }
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("lensd: " + data);
            }
        }

    }

    Timer {
        id: restart

        interval: 800
        onTriggered: daemon.running = true
    }

    // lens's own settings. only this process writes it, so it is not watched
    FileView {
        id: stateFile

        path: app.home + "/.local/state/lucid/lens.json"
        blockLoading: true
        printErrors: false
        onAdapterUpdated: writeLater.restart()
        onLoaded: app.stateReady = true
        onLoadFailed: (err) => {
            if (err === FileViewError.FileNotFound)
                writeLater.restart();

            app.stateReady = true;
        }

        adapter: JsonAdapter {
            id: state

            property int width: 1180
            property int height: 820
            property bool filmstrip: true
            // "theme" | "dark" | "black"
            property string background: "theme"
            property bool checker: true
            // what the mouse wheel does: "zoom" | "browse"
            property string wheel: "zoom"
            property bool wrap: false
            property int slideSecs: 5
            property bool shuffle: false
            property bool escCloses: true
            property bool confirmTrash: false
            // markup: the last tool, colour and size
            property string tool: "pen"
            property string ink: "red"
            property int inkSize: 2
            property bool fillShapes: false
            property string cropRatio: "free"
            // videos: listed with the pictures, played when shown, how loud
            property bool videos: true
            property bool autoplay: true
            property bool loopVideos: false
            property real volume: 1
            property bool muted: false
            // a trim encodes again, frame for frame, or cuts at keyframes
            property bool exactTrim: true
        }

    }

    Timer {
        id: writeLater

        interval: 150
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", app.home + "/.local/state/lucid"]);
            stateFile.writeAdapter();
        }
    }

    // lumen's settings, read only: how each folder is sorted, and whether hidden
    // files are shown. a change there re-sorts every open window
    FileView {
        path: app.home + "/.local/state/lucid/lumen.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var p = JSON.parse(text());
                app.lumen = {
                    "sortKey": p.sortKey || "name",
                    "sortDesc": p.sortDesc === true,
                    "folderSorts": p.folderSorts || {},
                    "hidden": p.hidden === true
                };
                app.lumenRev++;
            } catch (e) {
            }
        }
    }

    IpcHandler {
        // pictures opened from elsewhere get a window of their own, where they can
        // be seen; one opens its folder, several open as a set
        function open(paths: string): void {
            app.openPaths(paths);
        }

        function count(): int {
            return windows.count;
        }

        target: "lens"
    }

}
