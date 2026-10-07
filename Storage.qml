import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// what fills the disks and what could go; lucidprefs/storagetool.py does the
// looking. also warns when space runs low and empties old trash
Singleton {
    id: root

    readonly property string helper: Qt.resolvedUrl("lucidprefs/storagetool.py").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || root.home + "/.cache") + "/lucid/storage"
    readonly property bool watching: lowTimer.running

    // mounted filesystems and the drives under them, as storagetool.py reports them
    property var volumes: []
    property var drives: []
    property bool volumesReady: false

    // mount -> the last scan of it; trees are edited in place, so rev says when
    property var scans: ({})
    property int rev: 0
    // mounts whose cached scan has been looked for, found or not
    property var tried: ({})
    property string scanMount: ""
    property real scanFiles: 0
    property real scanBytes: 0
    property string scanError: ""
    property bool _scanDone: false
    property bool _scanCancelled: false
    readonly property bool scanning: root.scanMount !== ""
    // a folder being looked at more closely than the whole-disk pass did
    property string detailPath: ""
    property var _detailNode: null

    property var cleanup: null
    property bool measuring: false
    property string cleaning: ""
    property string trashing: ""
    property string lastError: ""
    // dev -> smartctl's answer
    property var health: ({})
    property string checking: ""
    property bool trimKnown: false
    property bool trimEnabled: false
    property string mounting: ""
    property string mountError: ""

    property var _warned: ({})
    property string _pendingLoad: ""

    signal cleaned(var result)
    signal trashed(string path, bool ok)

    function cachePath(mount) {
        return root.cacheDir + "/scan" + (mount === "/" ? "-root" : mount.replace(/[^A-Za-z0-9]+/g, "-")) + ".json";
    }

    function refreshVolumes() {
        if (!volProc.running)
            volProc.running = true;

    }

    function volume(mount) {
        for (var i = 0; i < root.volumes.length; i++) {
            if (root.volumes[i].mount === mount)
                return root.volumes[i];

        }
        return null;
    }

    // the cached scan if there is one; a missing file just marks it tried
    function ensure(mount) {
        if (!root.scans[mount] && !root.tried[mount])
            root.reload(mount);

    }

    function reload(mount) {
        if (loadProc.running) {
            root._pendingLoad = mount;
            return ;
        }
        loadProc.mount = mount;
        loadProc.command = ["cat", root.cachePath(mount)];
        loadProc.running = true;
    }

    function scan(mount) {
        if (root.scanning || mount === "")
            return ;

        root.scanMount = mount;
        root.scanFiles = 0;
        root.scanBytes = 0;
        root.scanError = "";
        root._scanDone = false;
        root._scanCancelled = false;
        scanProc.command = ["nice", "-n", "10", "python3", root.helper, "scan", mount, root.cachePath(mount)];
        scanProc.running = true;
    }

    function cancelScan() {
        if (!root.scanning)
            return ;

        root._scanCancelled = true;
        scanProc.running = false;
    }

    function detail(node, path) {
        if (root.detailPath !== "" || !node)
            return ;

        root._detailNode = node;
        root.detailPath = path;
        detailProc.command = ["nice", "-n", "10", "python3", root.helper, "scan", path, root.cacheDir + "/detail.json", String(Math.max(1, Math.round(node.s)))];
        detailProc.running = true;
    }

    // the scan holding path, and the chain of nodes from its root down to it
    function locate(path) {
        for (var m in root.scans) {
            var s = root.scans[m];
            if (!s || !s.tree)
                continue;

            var base = s.root === "/" ? "" : s.root;
            if (path !== s.root && path.indexOf(base + "/") !== 0)
                continue;

            var parts = path === s.root ? [] : path.substring(base.length + 1).split("/");
            var chain = [s.tree];
            var node = s.tree;
            for (var i = 0; i < parts.length && node; i++) {
                var next = null;
                var kids = node.c || [];
                for (var j = 0; j < kids.length; j++) {
                    if (kids[j].t !== 2 && kids[j].n === parts[i]) {
                        next = kids[j];
                        break;
                    }
                }
                node = next;
                if (node)
                    chain.push(node);

            }
            if (node)
                return {
                "scan": s,
                "chain": chain
            };

        }
        return null;
    }

    // drops a path the scans knew about, once it is gone from the disk
    function forget(path) {
        for (var m in root.scans) {
            var s = root.scans[m];
            if (!s)
                continue;

            var under = (p) => {
                return p === path || p.indexOf(path + "/") === 0;
            };
            if (s.large)
                s.large = s.large.filter((f) => {
                return !under(f.p);
            });

            if (s.dupes)
                s.dupes = s.dupes.map((g) => {
                var files = g.files.filter((f) => {
                    return !under(f.p);
                });
                return {
                    "size": g.size,
                    "files": files,
                    "waste": files.length > 1 ? files.reduce((a, f) => {
                        return a + f.s;
                    }, 0) - Math.max.apply(null, files.map((f) => {
                        return f.s;
                    })) : 0
                };
            }).filter((g) => {
                return g.files.length > 1;
            });

        }
        var at = root.locate(path);
        if (at && at.chain.length > 1) {
            var gone = at.chain[at.chain.length - 1];
            var parent = at.chain[at.chain.length - 2];
            parent.c = (parent.c || []).filter((n) => {
                return n !== gone;
            });
            for (var i = 0; i < at.chain.length - 1; i++) {
                at.chain[i].s = Math.max(0, at.chain[i].s - gone.s);
                if (gone.t === 0)
                    at.chain[i].f = Math.max(0, (at.chain[i].f || 0) - 1);
                else
                    at.chain[i].f = Math.max(0, (at.chain[i].f || 0) - (gone.f || 0));
            }
            at.scan.scanned = Math.max(0, at.scan.scanned - gone.s);
        }
        root.rev++;
    }

    function measure() {
        if (!cleanupProc.running) {
            root.measuring = true;
            cleanupProc.running = true;
        }
    }

    function clean(id) {
        if (root.cleaning !== "")
            return ;

        root.cleaning = id;
        root.lastError = "";
        cleanProc.command = ["python3", root.helper, "clean", id];
        cleanProc.running = true;
    }

    function trash(path) {
        if (root.trashing !== "" || path === "" || path === "/")
            return ;

        root.trashing = path;
        root.lastError = "";
        trashProc.command = ["gio", "trash", "--", path];
        trashProc.running = true;
    }

    function checkHealth(dev) {
        if (root.checking !== "")
            return ;

        root.checking = dev;
        healthProc.command = ["python3", root.helper, "health", dev];
        healthProc.running = true;
    }

    function setTrim(on) {
        if (trimSetProc.running)
            return ;

        trimSetProc.command = ["pkexec", "systemctl", on ? "enable" : "disable", "--now", "fstrim.timer"];
        trimSetProc.running = true;
    }

    // udisks: "mount" | "unmount" | "power-off"
    function udisks(verb, dev) {
        if (root.mounting !== "")
            return ;

        root.mounting = dev;
        root.mountError = "";
        mountProc.command = ["udisksctl", verb, "-b", dev];
        mountProc.running = true;
    }

    // unmounts what is mounted, then powers the drive down
    function eject(drive, parts) {
        if (root.mounting !== "")
            return ;

        root.mounting = drive;
        root.mountError = "";
        mountProc.command = ["sh", "-c", "d=\"$1\"; shift; for p in \"$@\"; do udisksctl unmount -b \"$p\" || exit 1; done; udisksctl power-off -b \"$d\"", "sh", drive].concat(parts);
        mountProc.running = true;
    }

    function open(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function uri(path) {
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
    }

    // the file manager with the item selected, or its folder if that fails
    function reveal(path) {
        Quickshell.execDetached(["sh", "-c", "dbus-send --session --print-reply --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1.ShowItems \"array:string:$1\" string: >/dev/null 2>&1 || xdg-open \"$(dirname \"$2\")\"", "sh", root.uri(path), path]);
    }

    function copyPath(path) {
        Quickshell.execDetached(["wl-copy", "--", path]);
    }

    function purgeTrash() {
        if (Prefs.storageTrashDays > 0 && !purgeProc.running) {
            purgeProc.command = ["python3", root.helper, "trash-old", String(Prefs.storageTrashDays)];
            purgeProc.running = true;
        }
    }

    function checkLow() {
        if (!Prefs.loaded || !Prefs.storageLowWarn)
            return ;

        var warned = Object.assign({}, root._warned);
        for (var i = 0; i < root.volumes.length; i++) {
            var v = root.volumes[i];
            if (!(v.root || v.home) || v.readonly)
                continue;

            var pct = v.avail / Math.max(1, v.used + v.avail) * 100;
            if (pct < Prefs.storageLowPercent) {
                if (!warned[v.mount]) {
                    warned[v.mount] = true;
                    root.notifyLow(v, pct);
                }
            } else if (pct > Prefs.storageLowPercent + 2) {
                warned[v.mount] = false;
            }
        }
        root._warned = warned;
    }

    function size(b) {
        if (!(b > 0))
            return "0 B";

        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return (i === 0 || b >= 100 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    function notifyLow(v, pct) {
        if (notifyProc.running)
            return ;

        notifyProc.command = ["notify-send", "-a", "Lucid", "-i", "drive-harddisk", "-u", pct < 3 ? "critical" : "normal", "Running out of space", "Only " + root.size(v.avail) + " is left on " + v.name + " (" + Math.round(pct) + "%).", "-A", "open=Free up space", "--wait"];
        notifyProc.running = true;
    }

    Component.onCompleted: firstLook.start()

    Connections {
        function onStorageTrashDaysChanged() {
            if (Prefs.loaded)
                purgeSoon.restart();

        }

        function onStorageLowPercentChanged() {
            if (Prefs.loaded)
                root.checkLow();

        }

        target: Prefs
    }

    Timer {
        id: firstLook

        interval: 45000
        onTriggered: {
            root.refreshVolumes();
            root.purgeTrash();
            root.probeTrim();
        }
    }

    Timer {
        id: lowTimer

        interval: 600000
        repeat: true
        running: Prefs.loaded && Prefs.storageLowWarn
        onTriggered: root.refreshVolumes()
    }

    Timer {
        interval: 21600000
        repeat: true
        running: Prefs.loaded && Prefs.storageTrashDays > 0
        onTriggered: root.purgeTrash()
    }

    Timer {
        id: purgeSoon

        interval: 3000
        onTriggered: root.purgeTrash()
    }

    function probeTrim() {
        if (!trimProc.running)
            trimProc.running = true;

    }

    Process {
        id: volProc

        command: ["python3", root.helper, "volumes"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text);
                    root.volumes = j.volumes || [];
                    root.drives = j.drives || [];
                    root.volumesReady = true;
                    root.checkLow();
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: loadProc

        property string mount: ""

        onExited: {
            if (root._pendingLoad !== "") {
                var next = root._pendingLoad;
                root._pendingLoad = "";
                Qt.callLater(root.reload, next);
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text !== "") {
                    try {
                        var j = JSON.parse(this.text);
                        var s = Object.assign({}, root.scans);
                        s[loadProc.mount] = j;
                        root.scans = s;
                        root.rev++;
                    } catch (e) {
                    }
                }
                var t = Object.assign({}, root.tried);
                t[loadProc.mount] = true;
                root.tried = t;
            }
        }

    }

    Process {
        id: scanProc

        onExited: (code) => {
            var m = root.scanMount;
            root.scanMount = "";
            if (root._scanDone)
                root.reload(m);
            else if (!root._scanCancelled)
                root.scanError = "The scan stopped before it finished.";

        }

        stdout: SplitParser {
            onRead: (line) => {
                var p = line.trim().split(" ");
                if (p.length >= 3 && (p[0] === "p" || p[0] === "d")) {
                    root.scanFiles = Number(p[1]);
                    root.scanBytes = Number(p[2]);
                    if (p[0] === "d")
                        root._scanDone = true;

                }
            }
        }

    }

    Process {
        id: detailProc

        property bool done: false

        onStarted: detailProc.done = false
        onExited: {
            if (detailProc.done) {
                detailRead.running = true;
            } else {
                root.detailPath = "";
                root._detailNode = null;
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("d ") === 0)
                    detailProc.done = true;

            }
        }

    }

    Process {
        id: detailRead

        command: ["cat", root.cacheDir + "/detail.json"]
        onExited: {
            root.detailPath = "";
            root._detailNode = null;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text);
                    var n = root._detailNode;
                    if (n && j.tree) {
                        n.c = j.tree.c || [];
                        n.f = j.tree.f;
                        n.d = 1;
                        root.rev++;
                    }
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: cleanupProc

        command: ["python3", root.helper, "cleanup"]
        onExited: root.measuring = false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.cleanup = JSON.parse(this.text);
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: cleanProc

        stdout: StdioCollector {
            onStreamFinished: {
                var j = null;
                try {
                    j = JSON.parse(this.text);
                } catch (e) {
                    j = {
                        "id": root.cleaning,
                        "ok": false,
                        "error": "no answer",
                        "freed": 0
                    };
                }
                root.cleaning = "";
                if (!j.ok && j.error !== "cancelled")
                    root.lastError = j.error;

                root.cleaned(j);
                root.measure();
                root.refreshVolumes();
                // the map is out of date wherever the clean reached
                if (j.ok && j.freed > 0) {
                    for (var m in root.scans) {
                        if (m === "/" || (root.volume(m) && root.volume(m).home)) {
                            root.scan(m);
                            break;
                        }
                    }
                }
            }
        }

    }

    Process {
        id: trashProc

        onExited: (code) => {
            var p = root.trashing;
            root.trashing = "";
            if (code === 0)
                root.forget(p);
            else
                root.lastError = "That could not be moved to the trash.";
            root.trashed(p, code === 0);
            root.measure();
            root.refreshVolumes();
        }
    }

    Process {
        id: healthProc

        stdout: StdioCollector {
            onStreamFinished: {
                var h = Object.assign({}, root.health);
                try {
                    h[root.checking] = JSON.parse(this.text);
                } catch (e) {
                    h[root.checking] = {
                        "ok": false,
                        "error": "no answer"
                    };
                }
                root.health = h;
                root.checking = "";
            }
        }

    }

    Process {
        id: trimProc

        command: ["systemctl", "is-enabled", "fstrim.timer"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.trimEnabled = this.text.trim() === "enabled";
                root.trimKnown = this.text.trim() !== "";
            }
        }

    }

    Process {
        id: trimSetProc

        onExited: root.probeTrim()
    }

    Process {
        id: mountProc

        onExited: (code) => {
            root.mounting = "";
            if (code !== 0)
                root.mountError = mountErr.text.trim().split("\n").pop() || "udisks refused.";

            root.refreshVolumes();
        }

        stderr: StdioCollector {
            id: mountErr
        }

    }

    Process {
        id: purgeProc

        onExited: root.refreshVolumes()
    }

    Process {
        id: notifyProc

        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() === "open")
                    Prefs.settingsRequested("storage");

            }
        }

    }

}
