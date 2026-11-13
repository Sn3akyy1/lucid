import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.lucidicons

// lumen's process-wide side: the file daemon, its own settings file, the open
// windows, transfers in flight and the undo list. lucid's prefs are only ever
// read here (for the icon theme); a second writer would clobber the shell's
Scope {
    id: app

    property string home: Quickshell.env("HOME")
    property string user: ""
    property var places: []
    property var bookmarks: []
    property var volumes: []
    // each drive's {free, total} by id: refreshed apart from the list, which keeps its rows
    property var volumeSpace: ({})
    property string volumesShape: ""
    // the os's name, for the drive it runs from
    property string systemName: "System"
    property int trashCount: 0
    property bool ready: false
    // settings -> environment -> use legacy icons: the gtk theme's icons, not lucid's
    property bool legacyIcons: false
    // the icon theme's own pictures for the sidebar's places, for legacy icons
    property var slotIcons: ({})
    // where gvfs shows every share it connects to, as plain folders, and the
    // kinds of address it can reach (smb:// only once gvfs-smb is in)
    property string remoteRoot: ""
    property var schemes: []
    // each connection being made, by its request: the window that asked, which
    // is where whatever the server asks on the way is shown
    property var _connects: ({})
    readonly property bool resident: Quickshell.env("LUMEN_BACKGROUND") === "1"
    property string desktopDir: app.home + "/Desktop"
    property string templatesDir: ""
    property int _nextId: 1
    property var _pending: ({})
    property var _queue: []
    property int _nextWin: 1
    property int _nextView: 1
    // transfers by job id, and what can still be undone, newest last
    property var jobs: ({})
    property int jobsRev: 0
    property var undoList: []
    property string iconTheme: ""
    property var focusedWindow: null
    property alias prefs: state
    // lumen's settings file has been read: a window opened before it would miss
    // the pinned tabs and the last dialog's folder, so those wait for it
    property bool stateReady: false
    property var _whenReady: []
    // a tab being dragged, {win, vid}: every window's strip and body know where
    // it came from while it is in the air
    property var tabDrag: null
    // the picture of files being dragged out of any window, for wherever they land
    // to show them arriving; "" when they come from another app
    property url dragImage
    // what a window is handed: inside its own scope `app` would be itself
    readonly property var lumenApp: app

    signal listEvent(var ev)
    signal listDoneEvent(var ev)
    signal searchEvent(var ev)
    signal searchDoneEvent(var ev)
    signal thumbEvent(string uri, string thumb)
    signal infoSizeEvent(var ev)
    signal jobFinished(var ev)
    // the icon theme or legacy mode changed: listings carry new icon paths
    signal iconsChanged()
    // the app took its open or save dialog back
    signal chooserClosed(int id)
    signal notice(string text, string action, var undo)
    // a server wants a password, or an answer, for a connection being made
    signal askEvent(var ev)
    signal askCloseEvent(int connect)
    // a drive or share went away: the tabs in it have to go somewhere else
    signal volumeGone(string path)

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
            console.warn("lumen: bad line from the daemon");
            return ;
        }
        if (m.id !== undefined && m.ev === undefined) {
            var cb = app._pending[m.id];
            if (cb) {
                delete app._pending[m.id];
                cb(m);
            } else if (m.ok === false) {
                console.warn("lumen: " + (m.error || "request failed"));
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
        case "list":
            app.listEvent(m);
            break;
        case "listDone":
            app.listDoneEvent(m);
            break;
        case "search":
            app.searchEvent(m);
            break;
        case "searchDone":
            app.searchDoneEvent(m);
            break;
        case "choose":
            app.openChooser(m);
            break;
        case "chooseClose":
            app.chooserClosed(m.id);
            break;
        case "thumb":
            app.thumbEvent(m.uri, m.thumb);
            break;
        case "trash":
            app.trashCount = m.count;
            break;
        case "bookmarks":
            app.bookmarks = m.items;
            break;
        case "volumes":
            app.setVolumes(m.items);
            break;
        case "infoSize":
            app.infoSizeEvent(m);
            break;
        case "ask":
            app.askEvent(m);
            break;
        case "askClose":
            app.askCloseEvent(m.connect);
            break;
        case "job":
            app.onJob(m);
            break;
        }
    }

    function hello() {
        app.call("hello", {
            "iconTheme": app.iconTheme,
            "legacy": app.legacyIcons
        }, function(r) {
            app.user = r.user || "";
            app.places = r.places || [];
            app.bookmarks = r.bookmarks || [];
            app.systemName = r.system || "System";
            app.setVolumes(r.volumes || []);
            app.trashCount = r.trash || 0;
            app.desktopDir = r.desktop || app.desktopDir;
            app.templatesDir = r.templates || "";
            app.slotIcons = r.slotIcons || ({});
            app.remoteRoot = r.remoteRoot || "";
            app.schemes = r.schemes || [];
        });
    }

    // ---- paths

    function normalise(p) {
        if (!p)
            return app.home;

        if (p.indexOf("file://") === 0)
            p = decodeURIComponent(p.slice(7));

        if (p === "~" || p.indexOf("~/") === 0)
            p = app.home + p.slice(1);

        if (p.length > 1 && p.charAt(p.length - 1) === "/" && p.indexOf("://") === -1)
            p = p.slice(0, -1);

        return p;
    }

    function parentOf(p) {
        if (p.indexOf("trash:") === 0)
            return app.home;

        // someone else's folder: up is the folder above as it is here, which goes
        // through admin:// again only if it has to
        if (p.indexOf("admin://") === 0) {
            var local = decodeURIComponent(p.replace(/^admin:\/\/[^\/]*/, "")).replace(/\/+$/, "");
            var j = local.lastIndexOf("/");
            return j <= 0 ? "/" : local.slice(0, j);
        }
        // an address goes up its own path, never above the server
        if (p.indexOf("://") !== -1) {
            var m = /^([a-z0-9+.-]+:\/\/[^\/]*)(\/.*)?$/i.exec(p);
            var rest = m && m[2] ? m[2].replace(/\/+$/, "") : "";
            if (rest === "")
                return p;

            var cut = rest.lastIndexOf("/");
            return m[1] + (cut <= 0 ? "/" : rest.slice(0, cut));
        }
        if (p === "/")
            return "/";

        // a share is as high as it goes: above it is gvfs's own folder of mounts
        if (app.remoteRoot !== "" && p.lastIndexOf("/") === app.remoteRoot.length && p.indexOf(app.remoteRoot + "/") === 0)
            return p;

        var i = p.lastIndexOf("/");
        return i <= 0 ? "/" : p.slice(0, i);
    }

    // the colours a tab or a bookmark can wear, each made from a seed at the tones
    // the wallpaper's own palette uses, so they sit right in light and dark
    readonly property var colours: [{
        "id": "red",
        "name": "Red",
        "seed": "#e53935"
    }, {
        "id": "orange",
        "name": "Orange",
        "seed": "#fb8c00"
    }, {
        "id": "yellow",
        "name": "Yellow",
        "seed": "#fdd835"
    }, {
        "id": "green",
        "name": "Green",
        "seed": "#43a047"
    }, {
        "id": "teal",
        "name": "Teal",
        "seed": "#00897b"
    }, {
        "id": "blue",
        "name": "Blue",
        "seed": "#1e88e5"
    }, {
        "id": "purple",
        "name": "Purple",
        "seed": "#8e24aa"
    }, {
        "id": "grey",
        "name": "Grey",
        "seed": "#8d8f99"
    }]

    function seedOf(id) {
        for (var i = 0; i < app.colours.length; i++) {
            if (app.colours[i].id === id)
                return app.colours[i].seed;

        }
        return "";
    }

    // ink for a glyph, the container behind one, and ink on that container
    function ink(id) {
        var s = app.seedOf(id);
        return s === "" ? Theme.text : Theme.atTone(Qt.lighter(s, 1), Theme.isLight ? 45 : 72);
    }

    function container(id) {
        var s = app.seedOf(id);
        return s === "" ? Theme.surfaceHigh : Theme.atTone(Qt.lighter(s, 1), Theme.isLight ? 90 : 30);
    }

    function onContainer(id) {
        var s = app.seedOf(id);
        return s === "" ? Theme.text : Theme.atTone(Qt.lighter(s, 1), Theme.isLight ? 12 : 90);
    }

    // the place a folder is, for its glyph: home, a home folder, a drive, or a folder
    function slotForPath(p) {
        if (p.indexOf("trash:") === 0)
            return app.trashCount > 0 ? "trash-full" : "trash";

        if (p.indexOf("recent:") === 0)
            return "recent";

        if (p.indexOf("network:") === 0)
            return "network";

        if (p === app.home)
            return "folder-home";

        if (p === "/")
            return "computer";

        for (var i = 0; i < app.places.length; i++) {
            if (app.places[i].path === p)
                return app.places[i].slot || "folder";

        }
        for (var j = 0; j < app.volumes.length; j++) {
            if (app.volumes[j].mounted && app.volumes[j].path === p)
                return app.volumes[j].slot || "drive";

        }
        return app.isRemote(p) ? "folder-remote" : "folder";
    }

    // ---- network: servers, and the shares they give

    // on another computer: in a share gvfs connected to, or an address
    function isRemote(p) {
        return (app.remoteRoot !== "" && p.indexOf(app.remoteRoot + "/") === 0) || app.isAddress(p);
    }

    // an address of somewhere else (smb://, sftp://, network:///), not a folder here
    function isAddress(p) {
        return /^[a-z][a-z0-9+.-]*:\/\//i.test(p) && !/^(file|trash|recent):/i.test(p);
    }

    // the server an address is on, as people say it
    function hostOf(uri) {
        if (uri.indexOf("network:") === 0)
            return "the network";

        var m = /^[a-z0-9+.-]+:\/\/(?:[^@\/]*@)?(\[[^\]]+\]|[^:\/]+)/i.exec(uri);
        return m ? decodeURIComponent(m[1]) : uri;
    }

    // computers nearby can be looked for: gvfs has a way to find them
    readonly property bool canDiscover: app.schemes.indexOf("dns-sd") !== -1 || app.schemes.indexOf("smb") !== -1 || app.schemes.indexOf("wsdd") !== -1

    // a connection asked for by a window, which is shown whatever the server
    // asks on the way. cb gets {ok, path, uri, label, isDir, name, where}, or
    // {ok: false, error, cancelled, missing}
    function connect(uri, owner, cb) {
        var id = app.call("connect", {
            "uri": uri
        }, function(r) {
            delete app._connects[id];
            if (cb)
                cb(r);

        });
        app._connects[id] = owner;
        return id;
    }

    function connectOwner(id) {
        return app._connects[id] || null;
    }

    // where the last dialog ended, unless that was a share no longer connected:
    // an app's dialog should not open on a login
    function lastChooserFolder() {
        var f = app.prefs.chooserFolder;
        return f !== "" && app.isRemote(f) && !app.volumeAt(f) ? "" : f;
    }

    // servers connected to by address, newest first, for the connect dialog
    function remember(uri, label) {
        var list = app.prefs.servers.filter(function(e) {
            return e.uri !== uri;
        });
        app.prefs.servers = [{
            "uri": uri,
            "label": label || app.hostOf(uri)
        }].concat(list).slice(0, 10);
    }

    function forgetServer(uri) {
        app.prefs.servers = app.prefs.servers.filter(function(e) {
            return e.uri !== uri;
        });
    }

    // pinned tabs, kept across windows: each is {key, path, colour}
    function addPin(key, path, colour) {
        app.prefs.pinnedTabs = app.prefs.pinnedTabs.filter(function(e) {
            return e.key !== key;
        }).concat([{
            "key": key,
            "path": path,
            "colour": colour || ""
        }]);
    }

    function updatePin(key, change) {
        var hit = false;
        var list = app.prefs.pinnedTabs.map(function(e) {
            if (e.key !== key)
                return e;

            hit = true;
            return {
                "key": e.key,
                "path": change.path !== undefined ? change.path : e.path,
                "colour": change.colour !== undefined ? change.colour : e.colour
            };
        });
        if (hit)
            app.prefs.pinnedTabs = list;

    }

    function dropPin(key) {
        app.prefs.pinnedTabs = app.prefs.pinnedTabs.filter(function(e) {
            return e.key !== key;
        });
    }

    function bookmarkColour(uri) {
        return app.prefs.bookmarkColours[uri] || "";
    }

    function setBookmarkColour(uri, id) {
        var m = Object.assign({}, app.prefs.bookmarkColours);
        if (id === "")
            delete m[uri];
        else
            m[uri] = id;
        app.prefs.bookmarkColours = m;
    }

    // ---- sorting: a folder keeps the sort it was given, the rest take the default

    // the trash and recent files start newest first
    function baseSort(path) {
        if (path.indexOf("trash:") === 0)
            return {
            "key": "deleted",
            "desc": true
        };

        if (path.indexOf("recent:") === 0)
            return {
            "key": "modified",
            "desc": true
        };

        return {
            "key": app.prefs.sortKey,
            "desc": app.prefs.sortDesc
        };
    }

    function sortOf(path) {
        var s = app.prefs.folderSorts[path] || app.baseSort(path);
        // the trash's date is when a thing went there; nothing else has one
        var trash = path.indexOf("trash:") === 0, key = s.key;
        if (trash && key === "modified")
            key = "deleted";
        else if (!trash && key === "deleted")
            key = "modified";
        return {
            "key": key,
            "desc": s.desc === true
        };
    }

    function setSort(path, key, desc) {
        var m = Object.assign({}, app.prefs.folderSorts), base = app.baseSort(path);
        // the newest last, so the oldest go first once there are too many
        delete m[path];
        if (base.key !== key || base.desc !== desc)
            m[path] = {
            "key": key,
            "desc": desc
        };

        var all = Object.keys(m);
        for (var i = 0; i < all.length - 400; i++) delete m[all[i]]
        app.prefs.folderSorts = m;
    }

    function isPlace(path) {
        return path.indexOf("trash:") === 0 || path.indexOf("recent:") === 0;
    }

    // folders sorted their own way, not counting the trash and recent files
    function ownSorts() {
        return Object.keys(app.prefs.folderSorts).filter(function(p) {
            return !app.isPlace(p);
        }).length;
    }

    // one sort for every folder: the default, with each folder's own let go.
    // the trash and recent files keep theirs. returns how to put it back
    function sortEverywhere(key, desc) {
        var was = {
            "kind": "sorts",
            "key": app.prefs.sortKey,
            "desc": app.prefs.sortDesc,
            "folders": app.prefs.folderSorts
        };
        var m = ({});
        for (var p in app.prefs.folderSorts) {
            if (app.isPlace(p))
                m[p] = app.prefs.folderSorts[p];

        }
        app.prefs.sortKey = key === "deleted" ? "modified" : key;
        app.prefs.sortDesc = desc;
        app.prefs.folderSorts = m;
        return was;
    }

    function isBookmarked(path) {
        for (var i = 0; i < app.bookmarks.length; i++) {
            if (app.bookmarks[i].path === path)
                return true;

        }
        return false;
    }

    function titleFor(p) {
        if (p.indexOf("trash:") === 0)
            return "Trash";

        if (p.indexOf("recent:") === 0)
            return "Recent";

        if (p === app.home)
            return "Home";

        if (p === "/")
            return app.systemName;

        if (p.indexOf("network:") === 0)
            return "Network";

        // an address by its folder, or by its server at the top
        if (p.indexOf("://") !== -1) {
            var tail = p.replace(/^[a-z0-9+.-]+:\/\/[^\/]*/i, "").replace(/\/+$/, "");
            return tail === "" ? app.hostOf(p) : decodeURIComponent(tail.slice(tail.lastIndexOf("/") + 1));
        }
        var v = app.volumeAt(p);
        if (v && v.path === p)
            return v.label;

        var i = p.lastIndexOf("/");
        return i >= 0 ? p.slice(i + 1) : p;
    }

    function setVolumes(items) {
        var space = {};
        var shape = items.map(function(v) {
            space[v.id] = {
                "free": v.free,
                "total": v.total
            };
            return [v.id, v.label, v.path, v.mounted, v.slot, v.canEject, v.canUnmount].join("|");
        }).join("\n");
        app.volumeSpace = space;
        if (shape !== app.volumesShape) {
            var was = app.volumes;
            app.volumesShape = shape;
            app.volumes = items;
            for (var i = 0; i < was.length; i++) {
                if (!was[i].mounted || !was[i].path || was[i].path === "/")
                    continue;

                var still = items.some(function(v) {
                    return v.mounted && v.path === was[i].path;
                });
                if (!still)
                    app.volumeGone(was[i].path);

            }
        }
    }

    // the mounted drive a path is on, other than the system's own
    function volumeAt(p) {
        var best = null;
        for (var i = 0; i < app.volumes.length; i++) {
            var v = app.volumes[i];
            if (!v.mounted || !v.path || v.path === "/")
                continue;

            if ((p === v.path || p.indexOf(v.path + "/") === 0) && (!best || v.path.length > best.path.length))
                best = v;

        }
        return best;
    }

    function uriOf(path) {
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
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
            return d.toLocaleDateString(Qt.locale(), "d MMM");

        return d.toLocaleDateString(Qt.locale(), "d MMM yyyy");
    }

    // the trash keeps local wall-clock time with no zone: 2026-10-11T18:01:22
    function deletedText(s) {
        var m = /^(\d+)-(\d+)-(\d+)T(\d+):(\d+):?(\d*)/.exec(s || "");
        if (!m)
            return s || "";

        var d = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0));
        return app.dateText(d.getTime() / 1000);
    }

    // ---- transfers

    function transfer(mode, uris, dest, label) {
        if (!uris || uris.length === 0 || !dest)
            return ;

        app.call("transfer", {
            "mode": mode,
            "uris": uris,
            "dest": dest
        }, function(r) {
            if (r.job === undefined)
                return ;

            var j = Object.assign({}, app.jobs);
            j[r.job] = {
                "job": r.job,
                "mode": mode,
                "state": "running",
                "done": 0,
                "total": 0,
                "files": 0,
                "count": uris.length,
                "name": "",
                "dest": dest,
                "label": label || "",
                "uris": uris
            };
            app.jobs = j;
            app.jobsRev++;
        });
    }

    function onJob(m) {
        var j = Object.assign({}, app.jobs);
        var cur = j[m.job] || {
            "job": m.job,
            "uris": []
        };
        j[m.job] = Object.assign(cur, m);
        if (m.state !== "running") {
            delete j[m.job];
            app.jobFinished(Object.assign({}, cur));
            var made = m.made || [];
            var moved = m.moved || [], copied = m.copied || [];
            var verb = moved.length === 0 && (copied.length > 0 || cur.mode === "copy") ? "Copied" : "Moved";
            if (m.tag === "undo" && m.state === "done" && (m.errors || []).length === 0)
                app.notice("Put back " + (made.length === 1 ? "“" + made[0].split("/").pop() + "”" : made.length + " items"), "", null);
            else if (m.state === "cancelled")
                app.notice(verb.replace("ed", "ing") + " stopped", "", null);
            else if ((m.errors || []).length > 0)
                app.notice((m.errors.length === 1 ? m.errors[0].error : m.errors.length + " items could not be " + verb.toLowerCase()), "", null);
            else if (made.length > 0) {
                var entry = {
                    "kind": "transfer",
                    "moved": moved,
                    "copied": copied
                };
                app.pushUndo(entry);
                app.notice(verb + " " + (made.length === 1 ? "“" + made[0].split("/").pop() + "”" : made.length + " items") + " to " + app.titleFor(cur.dest), "Undo", entry);
            }
        }
        app.jobs = j;
        app.jobsRev++;
    }

    function cancelJob(id) {
        app.call("cancelJob", {
            "job": id
        });
    }

    // ---- undo

    function pushUndo(entry) {
        if (!entry)
            return ;

        app.undoList = app.undoList.concat([entry]).slice(-30);
    }

    function undo() {
        if (app.undoList.length === 0) {
            app.notice("Nothing to undo", "", null);
            return ;
        }
        var e = app.undoList[app.undoList.length - 1];
        app.undoList = app.undoList.slice(0, -1);
        app.runUndo(e);
    }

    // undo from a snackbar: that entry, wherever it sits in the list
    function undoEntry(e) {
        app.undoList = app.undoList.filter(function(x) {
            return x !== e;
        });
        app.runUndo(e);
    }

    function runUndo(e) {
        if (e.kind === "trash") {
            app.call("restore", {
                "paths": e.paths
            }, function(r) {
                app.notice(r.ok ? "Restored " + (r.restored.length === 1 ? "“" + r.restored[0].split("/").pop() + "”" : r.restored.length + " items") : (r.error || "Could not restore"), "", null);
            });
        } else if (e.kind === "rename") {
            app.call("rename", {
                "uri": e.uri,
                "name": e.name
            });
        } else if (e.kind === "create") {
            app.takeBack(e.made.map(app.uriOf));
        } else if (e.kind === "sorts") {
            app.prefs.sortKey = e.key;
            app.prefs.sortDesc = e.desc;
            app.prefs.folderSorts = e.folders;
        } else if (e.kind === "transfer") {
            // what moved goes back where it came from, one job per folder; copies go
            var back = ({});
            for (var i = 0; i < e.moved.length; i++) {
                var home = app.parentOf(e.moved[i][0]);
                (back[home] = back[home] || []).push(app.uriOf(e.moved[i][1]));
            }
            for (var dest in back) app.call("transfer", {
                "mode": "move",
                "uris": back[dest],
                "dest": dest,
                "tag": "undo"
            })
            if (e.copied.length > 0)
                app.takeBack(e.copied.map(app.uriOf));

        }
    }

    // what lumen itself just made, undone: to the trash, or where there is no
    // trash (a share on a server) gone for good, being only a copy or new
    function takeBack(uris) {
        app.call("trash", {
            "uris": uris
        }, function(r) {
            var failed = (r.failed || []).map(function(f) {
                return f.uri;
            });
            if (failed.length > 0)
                app.call("delete", {
                "uris": failed
            });

        });
    }

    // ---- windows

    function openWindow(path) {
        app.openPaths(path);
    }

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

    // folders one a line: a window for the first, tabs in it for the rest
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
        if (list.length === 0)
            list = [app.home];

        windows.append({
            "wid": "w" + (app._nextWin++),
            "start": list[0],
            "more": list.slice(1).join("\n"),
            "chooser": "",
            "carry": ""
        });
    }

    // an app's open or save dialog, as an lumen window of its own, starting where
    // the app asked or where the last one ended
    function openChooser(req) {
        if (!app.stateReady) {
            app.whenReady(function() {
                app.openChooser(req);
            });
            return ;
        }
        idle.stop();
        windows.append({
            "wid": "w" + (app._nextWin++),
            "start": app.normalise(req.folder || app.lastChooserFolder() || app.home),
            "more": "",
            "chooser": JSON.stringify(req),
            "carry": ""
        });
    }

    function openTab(path) {
        // a tab in the window last used, or a window if there is none
        if (app.focusedWindow && app.focusedWindow.visible)
            app.focusedWindow.newTab(app.normalise(path));
        else
            app.openWindow(path);
    }

    function windowById(wid) {
        for (var i = 0; i < windowList.count; i++) {
            var w = windowList.objectAt(i);
            if (w && w.winId === wid)
                return w;

        }
        return null;
    }

    // a tab dropped where no strip took it: a window of its own, with its history
    function tearOff(state) {
        idle.stop();
        windows.append({
            "wid": "w" + (app._nextWin++),
            "start": state.path,
            "more": "",
            "chooser": "",
            "carry": JSON.stringify(state)
        });
    }

    // the move waits for the drag to end: taking a window's last tab closes it,
    // and the window must not go while its own drag is still running
    function transferLater(fromWid, vid, to, at) {
        transferWait.job = {
            "from": fromWid,
            "vid": vid,
            "to": to,
            "at": at
        };
        transferWait.restart();
    }

    // a tab dropped on another window: it leaves one and joins the other at `at`
    function transferTab(fromWid, vid, to, at) {
        var from = app.windowById(fromWid);
        if (!from || from === to)
            return ;

        var t = from.tabFor(vid);
        if (!t)
            return ;

        var state = from.exportTab(t);
        from.releaseTab(vid);
        to.adoptTab(state, at);
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

    // with no window left it lingers, so opening one again is instant, then goes
    // and gives its memory back. never mid-copy: the daemon's jobs die with it.
    // started for login (--background) it stays, ready for the file chooser
    function quitWhenIdle() {
        if (windows.count > 0 || app.resident)
            return ;

        if (Object.keys(app.jobs).length > 0)
            idle.restart();
        else
            Qt.quit();
    }

    function nextView() {
        return "v" + (app._nextView++);
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", app.home + "/.local/state/lucid"]);
        app.hello();
        // started at login it waits with no window; LUMEN_OPEN is folders, one a line
        if (Quickshell.env("LUMEN_BACKGROUND") !== "1")
            app.openPaths(Quickshell.env("LUMEN_OPEN") || "");

    }

    ListModel {
        id: windows
    }

    Timer {
        id: transferWait

        property var job: null

        interval: 60
        onTriggered: {
            var j = transferWait.job;
            transferWait.job = null;
            if (j)
                app.transferTab(j.from, j.vid, j.to, j.at);

        }
    }

    Timer {
        id: idle

        interval: Quickshell.env("LUMEN_EXIT_ON_CLOSE") === "1" ? 0 : 300000
        onTriggered: app.quitWhenIdle()
    }

    Instantiator {
        id: windowList

        model: windows

        delegate: LumenWindow {
            required property string wid
            required property string start
            required property string more
            required property string chooser
            required property string carry

            app: lumenApp
            winId: wid
            startPath: start
            morePaths: more
            chooserData: chooser
            carryData: carry
        }

    }

    Process {
        id: daemon

        command: ["python3", Qt.resolvedUrl("lumend.py").toString().replace("file://", "")]
        running: true
        stdinEnabled: true
        onExited: (code) => {
            app.ready = false;
            console.warn("lumen: the file daemon stopped (" + code + "), starting it again");
            restart.start();
        }

        stdout: SplitParser {
            onRead: (data) => {
                return app.receive(data);
            }
        }

        stderr: SplitParser {
            onRead: (data) => {
                return console.warn("lumend: " + data);
            }
        }

    }

    Timer {
        id: restart

        interval: 800
        onTriggered: {
            daemon.running = true;
            app.hello();
        }
    }

    // lumen's own settings, in its own file. only this process writes it, so it
    // is not watched: a watch would reload over a change made mid-write
    FileView {
        id: stateFile

        path: app.home + "/.local/state/lucid/lumen.json"
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

            property string view: "grid"
            property int iconSize: 80
            // where the last open or save dialog ended, for the next one
            property string chooserFolder: ""
            // the sort a folder takes unless it has its own
            property string sortKey: "name"
            property bool sortDesc: false
            // a folder's own sort by path, {key, desc}, only where it differs from the default
            property var folderSorts: ({})
            property bool foldersFirst: true
            property bool hidden: false
            property bool sidebar: true
            property bool preview: false
            property bool singleClick: false
            property bool confirmTrash: false
            property int width: 1120
            property int height: 720
            // tabs pinned in any window, opened at the front of every new one
            property var pinnedTabs: []
            // a colour id by bookmark uri; gtk's bookmarks file has nowhere for one
            property var bookmarkColours: ({})
            // servers connected to by address, newest first: [{uri, label}]
            property var servers: []
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

    // lucid's prefs, read only: which icon theme the system uses, whether lumen
    // shows it instead of its own, and which of lucid's sets its own are
    FileView {
        path: app.home + "/.config/quickshell/lucidprefs/prefs.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var p = JSON.parse(text());
                LucidIcons.set = p.envIconSet || "gravity";
                var t = p.envIconTheme || "", legacy = p.envLegacyIcons === true;
                if (t !== app.iconTheme || legacy !== app.legacyIcons) {
                    app.iconTheme = t;
                    app.legacyIcons = legacy;
                    // queued until the daemon is up, so hello can never miss it
                    app.call("theme", {
                        "iconTheme": t,
                        "legacy": legacy
                    }, function(r) {
                        if (r.slotIcons)
                            app.slotIcons = r.slotIcons;

                    });
                    app.iconsChanged();
                }
            } catch (e) {
            }
        }
    }

    IpcHandler {
        // a folder opened from elsewhere gets a window of its own, where it can be
        // seen; several, one a line, open as tabs of that window
        function open(path: string): void {
            app.openPaths(path);
        }

        function tab(path: string): void {
            app.openTab(path || app.home);
        }

        function window(path: string): void {
            app.openWindow(path || app.home);
        }

        function count(): int {
            return windows.count;
        }

        // copies and moves still running, which stopping it would cut short
        function busy(): int {
            return Object.keys(app.jobs).length;
        }

        target: "lumen"
    }

}
