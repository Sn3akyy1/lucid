import QtQuick
import qs
import qs.lucidicons

// one tab: a folder (or the trash, recent files, a search), its history, what is
// in it, what is selected. the daemon streams items in; they land in `model`,
// sorted and filtered, synced in place so a change on disk never resets the view
QtObject {
    id: tab

    required property var app
    required property string vid
    property string path: ""
    property var back: []
    property var forward: []
    property bool loading: false
    property string error: ""
    property var raw: []
    property var _incoming: []
    property var free: ({ "free": 0, "total": 0 })
    property bool writable: true
    // type-to-filter text, and a search below this folder when asked for
    property string filter: ""
    property bool searching: false
    property string searchQuery: ""
    property bool searchDone: true
    property bool searchTruncated: false
    property var _folderRaw: []
    // selection by uri; rev bumps on every change so delegates re-read it
    property var sel: ({})
    property int selCount: 0
    property int rev: 0
    property string anchorUri: ""
    property int current: -1
    property real scrollY: 0
    property var index: ({})
    property ListModel model: ListModel {
    }

    readonly property bool isTrash: tab.path.indexOf("trash:") === 0
    readonly property bool isRecent: tab.path.indexOf("recent:") === 0
    readonly property bool isSpecial: tab.isTrash || tab.isRecent
    readonly property bool isNetwork: tab.path.indexOf("network:") === 0
    readonly property string title: tab.searching ? tab.searchQuery : tab.app.titleFor(tab.path)
    readonly property int count: tab.model.count

    signal navigated()
    // which way the last move went: 1 into a folder, -1 back or up, for the view's push
    property int lastMove: 1
    // the model empties for a new folder or search: no one leaves with an animation then
    property bool clearing: false
    // a file dialog's kind of file: [[0, glob] or [1, mime type], ...]; folders always show
    property var rules: null
    // pinned: at the front of the strip, small, kept for every new window under
    // pinKey; colour: one of app.colours, or none
    property bool pinned: false
    property string pinKey: ""
    property string colour: ""
    // the sort the model was last put in, to tell when a change is this tab's
    property string _sortSpec: ""
    // a share that isn't connected: the address to connect to, whether the
    // window is connecting now, and whether this look was asked for (a look
    // the daemon makes by itself never brings up a login)
    property string connectUri: ""
    property bool connecting: false
    property bool wantConnect: false
    // an address typed in: kept with the recent servers once it connects
    property string rememberNext: ""
    // someone else's folder: shut until gvfs's admin:// opens it with a password
    // (whose it is), and open that way now
    readonly property bool locked: tab.connectUri.indexOf("admin:") === 0
    property string lockedOwner: ""
    readonly property bool asAdmin: tab.path.indexOf("admin:") === 0

    onPathChanged: {
        if (tab.pinned && tab.pinKey !== "" && tab.path !== "")
            tab.app.updatePin(tab.pinKey, {
            "path": tab.path
        });

    }

    // ---- moving around

    function go(path, keepHistory, move) {
        if (!path)
            return ;

        path = tab.app.normalise(path);
        if (path === tab.path && !tab.searching) {
            tab.reload();
            return ;
        }
        if (tab.path !== "" && !keepHistory) {
            tab.back = tab.back.concat([tab.path]).slice(-60);
            tab.forward = [];
        }
        tab.path = path;
        tab.searching = false;
        tab.filter = "";
        tab.clearSelection();
        tab.current = -1;
        tab.scrollY = 0;
        tab.lastMove = move || 1;
        tab.load(true);
        tab.navigated();
    }

    function goBack() {
        if (tab.back.length === 0)
            return ;

        var prev = tab.back[tab.back.length - 1];
        tab.forward = [tab.path].concat(tab.forward).slice(0, 60);
        tab.back = tab.back.slice(0, -1);
        tab.go(prev, true, -1);
    }

    function goForward() {
        if (tab.forward.length === 0)
            return ;

        var next = tab.forward[0];
        tab.back = tab.back.concat([tab.path]);
        tab.forward = tab.forward.slice(1);
        tab.go(next, true, 1);
    }

    function goUp() {
        var up = tab.app.parentOf(tab.path);
        if (up && up !== tab.path)
            tab.go(up, false, -1);
    }

    function reload() {
        tab.load(false);
    }

    function load(fresh) {
        tab.loading = true;
        tab.error = "";
        tab.connectUri = "";
        tab.connecting = false;
        tab.wantConnect = true;
        if (fresh) {
            tab.clearing = true;
            tab.model.clear();
            tab.clearing = false;
            tab.raw = [];
            tab.index = ({});
        }
        tab._incoming = [];
        tab.app.call("list", {
            "view": tab.vid,
            "path": tab.path,
            "hidden": tab.app.prefs.hidden
        });
    }

    // ---- what the daemon sends

    function onList(ev) {
        if (ev.path !== tab.path || tab.searching)
            return ;

        if (ev.reset)
            tab._incoming = [];

        tab._incoming = tab._incoming.concat(ev.items);
        if (ev.error && !ev.connect)
            tab.error = ev.error;

        // a fresh folder shows its first batch at once; the rest lands together
        if (ev.reset && tab.model.count === 0 && ev.items.length > 0) {
            tab.raw = tab._incoming;
            tab.apply();
        }
    }

    function onListDone(ev) {
        if (ev.path !== tab.path || tab.searching)
            return ;

        tab.raw = tab._incoming;
        tab._incoming = [];
        tab.loading = false;
        // a folder that couldn't be read has no room to tell
        if (ev.free || ev.error)
            tab.free = ev.free || {
            "free": 0,
            "total": 0
        };

        tab.writable = ev.writable !== false && !tab.isRecent;
        tab.connectUri = ev.connect || "";
        tab.lockedOwner = ev.owner || "";
        if (tab.locked)
            tab.error = "An administrator's password opens it.";
        else if (ev.connect)
            tab.error = "Not connected to " + tab.app.hostOf(ev.connect);
        else if (ev.error)
            tab.error = ev.error;
        tab.apply();
    }

    function onSearch(ev) {
        if (!tab.searching)
            return ;

        if (ev.reset) {
            tab.raw = [];
            tab.clearing = true;
            tab.model.clear();
            tab.clearing = false;
            tab.index = ({});
        }
        tab.raw = tab.raw.concat(ev.items);
        tab.apply();
    }

    function onSearchDone(ev) {
        if (!tab.searching)
            return ;

        tab.searchDone = true;
        tab.searchTruncated = ev.truncated === true;
        tab.loading = false;
        tab.apply();
    }

    function onThumb(uri, thumb) {
        var i = tab.index[uri];
        if (i !== undefined && i < tab.model.count && tab.model.get(i).uri === uri)
            tab.model.setProperty(i, "thumb", thumb);

        for (var k = 0; k < tab.raw.length; k++) {
            if (tab.raw[k].uri === uri) {
                tab.raw[k].thumb = thumb;
                break;
            }
        }
    }

    // ---- searching below this folder

    function search(query) {
        query = (query || "").trim();
        if (query === "") {
            tab.endSearch();
            return ;
        }
        if (!tab.searching)
            tab._folderRaw = tab.raw;

        // the query first: the window's search field reads it on searchingChanged
        tab.searchQuery = query;
        tab.searching = true;
        tab.searchDone = false;
        tab.searchTruncated = false;
        tab.loading = true;
        tab.filter = "";
        tab.clearSelection();
        tab.app.call("search", {
            "view": tab.vid,
            // the whole disk: home first, then the rest of it
            "root": "/",
            "query": query,
            "hidden": tab.app.prefs.hidden
        });
    }

    function endSearch() {
        if (!tab.searching)
            return ;

        tab.searching = false;
        tab.searchQuery = "";
        tab.loading = false;
        tab.app.call("search", {
            "view": tab.vid,
            "root": "",
            "query": ""
        });
        tab.raw = tab._folderRaw;
        tab.clearing = true;
        tab.model.clear();
        tab.clearing = false;
        tab.index = ({});
        tab.apply();
        tab.reload();
    }

    // ---- sorting, filtering and keeping the model in step

    function natural(a, b) {
        var ra = /(\d+)|(\D+)/g, rb = /(\d+)|(\D+)/g;
        a = a.toLowerCase();
        b = b.toLowerCase();
        for (; ; ) {
            var ma = ra.exec(a), mb = rb.exec(b);
            if (!ma || !mb)
                return (ma ? 1 : 0) - (mb ? 1 : 0);

            if (ma[1] !== undefined && mb[1] !== undefined) {
                var d = Number(ma[1]) - Number(mb[1]);
                if (d !== 0)
                    return d;

                if (ma[1].length !== mb[1].length)
                    return ma[1].length - mb[1].length;

            } else if (ma[0] !== mb[0]) {
                return ma[0] < mb[0] ? -1 : 1;
            }
        }
    }

    function sortSpec() {
        var s = tab.app.sortOf(tab.path);
        return s.key + (s.desc ? ":desc" : ":asc") + (tab.app.prefs.foldersFirst ? ":dirs" : "");
    }

    // a sort changed somewhere: this tab moves only if it was its own
    function resort() {
        if (tab.sortSpec() !== tab._sortSpec)
            tab.apply();

    }

    // what the last column shows: where a thing came from or lies, or its type
    function typeOf(it) {
        return tab.isTrash ? tab.app.parentOf(it.orig || "") : (it.where || it.desc || "");
    }

    function sorted(list) {
        var s = tab.app.sortOf(tab.path), key = s.key, desc = s.desc, dirsFirst = tab.app.prefs.foldersFirst;
        tab._sortSpec = tab.sortSpec();
        var nat = tab.natural, typeOf = tab.typeOf;
        var out = list.slice();
        out.sort(function(a, b) {
            if (dirsFirst && (a.kind === "dir") !== (b.kind === "dir"))
                return a.kind === "dir" ? -1 : 1;

            var r = 0;
            if (key === "size")
                r = (a.kind === "dir" ? -1 : a.size) - (b.kind === "dir" ? -1 : b.size);
            else if (key === "modified")
                r = a.mtime - b.mtime;
            else if (key === "type")
                r = typeOf(a).localeCompare(typeOf(b));
            else if (key === "deleted")
                r = (a.deleted || "").localeCompare(b.deleted || "");
            if (r !== 0)
                return desc ? -r : r;

            // a tie goes by name, a to z, whichever way the rest runs
            r = nat(a.label || a.name, b.label || b.name);
            return key === "name" && desc ? -r : r;
        });
        return out;
    }

    function matches(it, rules) {
        var name = (it.name || "").toLowerCase(), mime = it.mime || "";
        for (var i = 0; i < rules.length; i++) {
            var kind = rules[i][0], pat = String(rules[i][1]);
            if (kind === 1) {
                if (pat === mime || pat === "*/*" || (pat.slice(-2) === "/*" && mime.indexOf(pat.slice(0, -1)) === 0))
                    return true;

            } else {
                var re = "^" + pat.toLowerCase().replace(/[.+^${}()|\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$";
                if (new RegExp(re).test(name))
                    return true;

            }
        }
        return false;
    }

    function visibleItems() {
        var f = tab.filter.trim().toLowerCase();
        var list = tab.raw;
        var rules = tab.rules;
        if (rules && rules.length > 0)
            list = list.filter(function(it) {
                return it.kind === "dir" || tab.matches(it, rules);
            });

        if (f !== "")
            list = list.filter(function(it) {
                return (it.label || it.name).toLowerCase().indexOf(f) !== -1;
            });

        return tab.searching && !tab.searchDone ? list : tab.sorted(list);
    }

    function row(it) {
        // every role on every row, or a listmodel drops what the first lacked
        return {
            "name": it.name || "",
            "label": it.label || it.name || "",
            "path": it.path || "",
            "uri": it.uri || "",
            "kind": it.kind || "file",
            "mime": it.mime || "",
            "desc": it.desc || "",
            // a launcher wears its app's own tile when the icon theme has one
            "slot": (it.kind === "app" ? LucidIcons.appSlot(it.appId, it.wmClass, it.iconName, it.label, it.cats) : "") || it.slot || "file",
            "icon": it.icon || "",
            "thumb": it.thumb || "",
            "size": it.size || 0,
            "mtime": it.mtime || 0,
            "hidden": it.hidden === true,
            "link": it.link === true,
            "exec": it.exec === true,
            "orig": it.orig || "",
            "deleted": it.deleted || "",
            "where": it.where || ""
        };
    }

    // the model walks to the new order with the fewest moves, so delegates,
    // their thumbnails and the scroll position all survive a refresh
    function apply() {
        var want = tab.visibleItems();
        var m = tab.model;
        var keep = ({});
        for (var i = 0; i < want.length; i++) keep[want[i].uri] = true
        for (var j = m.count - 1; j >= 0; j--) {
            if (!keep[m.get(j).uri])
                m.remove(j);

        }
        var at = ({});
        for (var k = 0; k < m.count; k++) at[m.get(k).uri] = k
        for (var n = 0; n < want.length; n++) {
            var w = tab.row(want[n]);
            if (n < m.count && m.get(n).uri === w.uri) {
                var cur = m.get(n);
                if (cur.mtime !== w.mtime || cur.size !== w.size || cur.label !== w.label || (w.thumb && cur.thumb !== w.thumb) || cur.slot !== w.slot || cur.icon !== w.icon)
                    m.set(n, w);

                continue;
            }
            var found = -1;
            for (var s = n + 1; s < m.count; s++) {
                if (m.get(s).uri === w.uri) {
                    found = s;
                    break;
                }
            }
            if (found >= 0) {
                m.move(found, n, 1);
                m.set(n, w);
            } else {
                m.insert(n, w);
            }
        }
        while (m.count > want.length)m.remove(m.count - 1)
        var idx = ({});
        for (var q = 0; q < m.count; q++) idx[m.get(q).uri] = q
        tab.index = idx;
        // a selection only holds what is still there
        var nsel = ({}), c = 0;
        for (var u in tab.sel) {
            if (idx[u] !== undefined) {
                nsel[u] = true;
                c++;
            }
        }
        tab.sel = nsel;
        tab.selCount = c;
        if (tab.current >= m.count)
            tab.current = m.count - 1;

        tab.rev++;
    }

    // ---- selection

    function isSelected(uri) {
        return tab.sel[uri] === true;
    }

    function clearSelection() {
        tab.sel = ({});
        tab.selCount = 0;
        tab.anchorUri = "";
        tab.rev++;
    }

    function selectOnly(i) {
        if (i < 0 || i >= tab.model.count) {
            tab.clearSelection();
            return ;
        }
        var s = ({});
        var u = tab.model.get(i).uri;
        s[u] = true;
        tab.sel = s;
        tab.selCount = 1;
        tab.anchorUri = u;
        tab.current = i;
        tab.rev++;
    }

    function toggle(i) {
        var u = tab.model.get(i).uri;
        var s = Object.assign({}, tab.sel);
        if (s[u]) {
            delete s[u];
            tab.selCount--;
        } else {
            s[u] = true;
            tab.selCount++;
        }
        tab.sel = s;
        tab.anchorUri = u;
        tab.current = i;
        tab.rev++;
    }

    function selectRange(i, additive) {
        var a = tab.anchorUri !== "" && tab.index[tab.anchorUri] !== undefined ? tab.index[tab.anchorUri] : i;
        var lo = Math.min(a, i), hi = Math.max(a, i);
        var s = additive ? Object.assign({}, tab.sel) : ({});
        for (var k = lo; k <= hi; k++) s[tab.model.get(k).uri] = true
        tab.sel = s;
        tab.selCount = Object.keys(s).length;
        tab.current = i;
        tab.rev++;
    }

    function selectSet(indexes, additive) {
        var s = additive ? Object.assign({}, tab.sel) : ({});
        for (var k = 0; k < indexes.length; k++) s[tab.model.get(indexes[k]).uri] = true
        tab.sel = s;
        tab.selCount = Object.keys(s).length;
        tab.rev++;
    }

    function selectAll() {
        var s = ({});
        for (var k = 0; k < tab.model.count; k++) s[tab.model.get(k).uri] = true
        tab.sel = s;
        tab.selCount = tab.model.count;
        tab.rev++;
    }

    function selectedItems() {
        var out = [];
        for (var k = 0; k < tab.model.count; k++) {
            var it = tab.model.get(k);
            if (tab.sel[it.uri])
                out.push(tab.row(it));

        }
        return out;
    }

    function selectByName(name) {
        for (var k = 0; k < tab.model.count; k++) {
            if (tab.model.get(k).name === name) {
                tab.selectOnly(k);
                return k;
            }
        }
        return -1;
    }

    Component.onDestruction: tab.app.call("unwatch", {
        "view": tab.vid
    })
}
