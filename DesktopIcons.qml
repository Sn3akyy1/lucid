pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// the files on the desktop and where each one sits. Icons keep to a grid and
// each remembers a cell of its own. A widget always wins the space: an icon it
// covers - even mid-drag - steps to the nearest free cell, and goes back once
// the widget moves off. Widgets never move for icons.
Singleton {
    id: root

    // on in Settings, and not put away from the desktop's menu
    readonly property bool live: Prefs.loaded && Prefs.desktopIcons && Prefs.desktopIconsShown
    readonly property string script: Qt.resolvedUrl("./luciddesktop/desktop-icons.py").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")

    // what the helper last reported
    property string dir: ""
    property bool dirExists: true
    property var files: []
    property int trashCount: 0
    property bool listed: false

    // ---- what is on show -------------------------------------------------

    // { key, name, label, kind, path, uri, mime, icons, thumb, exec, link, mtime, size },
    // the specials first and then the folder in the arrange order
    readonly property var items: {
        var out = [];
        if (Prefs.desktopIconsHome)
            out.push({
                "key": "::home",
                "name": "",
                "label": "Home",
                "kind": "home",
                "path": root.home,
                "uri": "file://" + root.home,
                "mime": "inode/directory",
                "icons": ["user-home", "folder-home", "folder"],
                "thumb": "",
                "exec": false,
                "link": false,
                "mtime": 0,
                "size": 0
            });
        if (Prefs.desktopIconsTrash)
            out.push({
                "key": "::trash",
                "name": "",
                "label": "Trash",
                "kind": "trash",
                "path": "",
                "uri": "trash:///",
                "mime": "",
                "icons": root.trashCount > 0 ? ["user-trash-full", "user-trash"] : ["user-trash", "user-trash-full"],
                "thumb": "",
                "exec": false,
                "link": false,
                "mtime": 0,
                "size": 0
            });
        var f = root.files.slice();
        f.sort(root.comparer(Prefs.desktopIconsSort));
        for (var i = 0; i < f.length; i++) {
            var e = f[i];
            out.push({
                "key": e.name,
                "name": e.name,
                "label": e.label,
                "kind": e.kind,
                "path": e.path,
                "uri": e.uri,
                "mime": e.mime,
                "icons": e.icons,
                "thumb": e.thumb,
                "exec": e.exec,
                "link": e.link,
                "mtime": e.mtime,
                "size": e.size
            });
        }
        return out;
    }
    readonly property var byKey: {
        var m = {};
        for (var i = 0; i < root.items.length; i++)
            m[root.items[i].key] = root.items[i];
        return m;
    }

    function comparer(how) {
        var byName = (a, b) => a.label.localeCompare(b.label, undefined, {
            "numeric": true,
            "sensitivity": "base"
        });
        if (how === "date")
            return (a, b) => (b.mtime - a.mtime) || byName(a, b);

        if (how === "type")
            return (a, b) => {
                var da = a.kind === "dir" ? 0 : (a.kind === "app" ? 1 : 2);
                var db = b.kind === "dir" ? 0 : (b.kind === "app" ? 1 : 2);
                return (da - db) || a.mime.localeCompare(b.mime) || byName(a, b);
            };

        return (a, b) => {
            var da = a.kind === "dir" ? 0 : 1;
            var db = b.kind === "dir" ? 0 : 1;
            return (da - db) || byName(a, b);
        };
    }

    // ---- the grid ----------------------------------------------------------

    readonly property var screen: Monitors.mainScreen
    readonly property real screenW: root.screen ? root.screen.width : 1920
    readonly property real screenH: root.screen ? root.screen.height : 1080
    readonly property int iconPx: Theme.dp(Prefs.desktopIconSize === "small" ? 32 : (Prefs.desktopIconSize === "large" ? 64 : 48))
    // the icon's own footprint, and the grid pitch: whatever is left over after
    // the last whole column (or row) is shared out, so the grid reaches both
    // edges instead of stopping short of the right one
    readonly property real tileW: root.iconPx + Theme.dp(48)
    readonly property real tileH: root.iconPx + Theme.dp(50)
    readonly property real cellW: (root.screenW - 2 * root.pad) / root.cols
    readonly property real cellH: (root.screenH - root.reserveTop - root.reserveBottom - 2 * root.pad) / root.rows
    readonly property real pad: Theme.dp(10)
    // the bar's strip and a dock that stays up are never under an icon
    readonly property real reserveTop: Prefs.barEnabled ? Prefs.effectiveBarTopMargin + Theme.dp(Prefs.barHeight) : 0
    readonly property real reserveBottom: Widgets.spawnBottom
    readonly property real areaY: root.reserveTop + root.pad
    readonly property int cols: Math.max(1, Math.floor((root.screenW - 2 * root.pad) / root.tileW))
    readonly property int rows: Math.max(1, Math.floor((root.screenH - root.reserveTop - root.reserveBottom - 2 * root.pad) / root.tileH))
    // columns count from the corner the icons start in
    readonly property bool fromRight: Prefs.desktopIconsCorner === "right"

    function cellX(c) {
        return root.fromRight ? root.screenW - root.pad - (c + 1) * root.cellW : root.pad + c * root.cellW;
    }

    function cellY(r) {
        return root.areaY + r * root.cellH;
    }

    // where the icon itself sits inside its cell
    // whole pixels: the shared-out pitch is fractional, and an icon or a name
    // half a pixel off is drawn soft
    function tileX(c) {
        return Math.round(root.cellX(c) + (root.cellW - root.tileW) / 2);
    }

    function tileY(r) {
        return Math.round(root.cellY(r) + (root.cellH - root.tileH) / 2);
    }

    function cellAt(px, py) {
        var c = root.fromRight ? Math.floor((root.screenW - root.pad - px) / root.cellW) : Math.floor((px - root.pad) / root.cellW);
        var r = Math.floor((py - root.areaY) / root.cellH);
        return {
            "c": Math.max(0, Math.min(root.cols - 1, c)),
            "r": Math.max(0, Math.min(root.rows - 1, r))
        };
    }

    // ---- names on the wallpaper --------------------------------------------

    // how light the wallpaper is across the screen (L*, 0 to 100, on a coarse
    // grid), so a name over a white sky can turn dark instead of hiding behind
    // a smudge of shade
    property var luma: ({
        "cols": 0,
        "rows": 0,
        "l": []
    })
    property string lumaFor: ""

    // the average lightness of the wallpaper under a screen rectangle; -1 if
    // it is not known yet
    function lumaAt(x, y, w, h) {
        var g = root.luma;
        if (!g.cols || g.l.length !== g.cols * g.rows)
            return -1;

        var c0 = Math.max(0, Math.floor(x / root.screenW * g.cols));
        var c1 = Math.min(g.cols - 1, Math.floor((x + w) / root.screenW * g.cols));
        var r0 = Math.max(0, Math.floor(y / root.screenH * g.rows));
        var r1 = Math.min(g.rows - 1, Math.floor((y + h) / root.screenH * g.rows));
        var sum = 0;
        var n = 0;
        for (var r = r0; r <= r1; r++) {
            for (var c = c0; c <= c1; c++) {
                sum += g.l[r * g.cols + c];
                n++;
            }
        }
        return n ? sum / n : -1;
    }

    function measureWallpaper(path) {
        if (path === "" || !root.live)
            return ;

        root.lumaFor = path;
        lumaProc.running = false;
        lumaProc.command = ["python3", root.script, "luma", path, String(root.screenW), String(root.screenH)];
        lumaProc.running = true;
    }

    FileView {
        id: wallFile

        path: root.home + "/.cache/current_wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.measureWallpaper(wallFile.text().trim())
    }

    Process {
        id: lumaProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.luma = JSON.parse(text);
                } catch (e) {
                }
            }
        }
    }

    // what a name says at rest: a file's extension left off when the icon
    // already tells the kind (a print, a sheet with its type on a tab), the
    // whole name under the pointer, selected, or being renamed
    function shortLabel(it) {
        if (!it || it.kind !== "file")
            return it ? it.label : "";

        var l = it.label;
        var dot = l.lastIndexOf(".");
        if (dot <= 0 || l.length - dot - 1 > 5 || l.length - dot - 1 < 1)
            return l;

        return l.slice(0, dot);
    }

    // a file's type, for the tab on its sheet: the extension, or nothing
    function typeTag(it) {
        if (!it || it.kind !== "file")
            return "";

        var l = it.label;
        var dot = l.lastIndexOf(".");
        if (dot <= 0 || l.length - dot - 1 > 5)
            return "";

        return l.slice(dot + 1).toUpperCase();
    }

    // names shown only while the pointer is among the icons: they come out in
    // a wave from the one under it, and go after a moment away
    readonly property bool namesOnHover: Prefs.desktopIconNames === "hover"
    property string hoverKey: ""
    property bool namesOut: false
    property var namesFrom: ({
        "c": 0,
        "r": 0
    })

    onHoverKeyChanged: {
        if (root.hoverKey !== "") {
            namesAway.stop();
            if (!root.namesOut) {
                var p = root.placed[root.hoverKey];
                if (p)
                    root.namesFrom = {
                    "c": p.c,
                    "r": p.r
                };

                root.namesOut = true;
            }
        } else {
            namesAway.restart();
        }
    }

    // how tall each icon's card stands (a long name grows it), so the frosting
    // behind a card fits it
    property var cardH: ({})

    function noteCard(key, h) {
        if (key === "" || root.cardH[key] === h)
            return ;

        var m = Object.assign({}, root.cardH);
        m[key] = h;
        root.cardH = m;
    }

    Timer {
        id: namesAway

        interval: 700
        onTriggered: root.namesOut = false
    }

    // ---- where everything sits ---------------------------------------------

    // key -> [c, r]: the cell each icon calls its own, persisted
    property var homes: ({})
    // key -> { c, r, away }: where it is drawn. away = a widget holds its home
    property var placed: ({})
    // the widgets' rectangles on the main screen, padded a little
    property var widgetRects: []

    readonly property real widgetGap: Theme.dp(6)

    function collectWidgets() {
        var out = [];
        if (Prefs.widgetsEnabled) {
            var m = Widgets.model;
            for (var i = 0; i < m.count; i++) {
                var e = m.get(i);
                if (e.closing || !Widgets.onPrimary(e))
                    continue;

                var k = Widgets.sizeScale(e.wtype, e.wvariant);
                var w = e.bw * e.zoom * k;
                var h = e.bh * e.zoom * k;
                var x = Math.max(0, Math.min(root.screenW - w, e.wx));
                var y = Math.max(0, Math.min(root.screenH - h, e.wy));
                if (Widgets.liveUid !== "" && e.uid === Widgets.liveUid) {
                    x = Widgets.liveRect.x;
                    y = Widgets.liveRect.y;
                    w = Widgets.liveRect.width;
                    h = Widgets.liveRect.height;
                }
                var t = Widgets.typeAt(e.wtype);
                out.push({
                    "name": t ? t.name : "",
                    "x": x - root.widgetGap,
                    "y": y - root.widgetGap,
                    "w": w + 2 * root.widgetGap,
                    "h": h + 2 * root.widgetGap
                });
            }
        }
        root.widgetRects = out;
    }

    function blockedGrid() {
        var b = new Array(root.cols * root.rows);
        for (var c = 0; c < root.cols; c++) {
            for (var r = 0; r < root.rows; r++)
                b[c * root.rows + r] = root.widgetOn(c, r) >= 0;
        }
        return b;
    }

    // which of the widget rectangles covers a cell, or -1
    function widgetOn(c, r) {
        var x0 = root.tileX(c) + 4;
        var x1 = x0 + root.tileW - 8;
        var y0 = root.tileY(r) + 4;
        var y1 = y0 + root.tileH - 8;
        var rects = root.widgetRects;
        for (var i = 0; i < rects.length; i++) {
            var q = rects[i];
            if (x0 < q.x + q.w && x1 > q.x && y0 < q.y + q.h && y1 > q.y)
                return i;

        }
        return -1;
    }

    // where a drag of our own icons would put one of them, from the cell under
    // the pointer: { c, r, widget, lc, lr } - widget = the rectangle in the way
    // (or -1), lc/lr = where it lands then: the nearest free cell, the way
    // relayout() steps it aside once the icons that stay have their cells
    function dragSpot(key) {
        var from = root.placed[key];
        var anchor = root.placed[root.dragKey];
        if (!from || !anchor)
            return null;

        var to = root.cellAt(root.dragX, root.dragY);
        var c = Math.max(0, Math.min(root.cols - 1, from.c + to.c - anchor.c));
        var r = Math.max(0, Math.min(root.rows - 1, from.r + to.r - anchor.r));
        var w = root.widgetOn(c, r);
        var lc = c;
        var lr = r;
        if (w >= 0) {
            var taken = new Array(root.cols * root.rows);
            var keys = Object.keys(root.placed);
            for (var i = 0; i < keys.length; i++) {
                if (root.dragKeys.indexOf(keys[i]) < 0)
                    taken[root.placed[keys[i]].c * root.rows + root.placed[keys[i]].r] = true;

            }
            var spot = root.nearestFree(c, r, root.blockedGrid(), taken);
            if (spot >= 0) {
                lc = Math.floor(spot / root.rows);
                lr = spot % root.rows;
            }
        }
        return {
            "c": c,
            "r": r,
            "widget": w,
            "lc": lc,
            "lr": lr
        };
    }

    // the widgets a drag of our own icons is running into, by index
    readonly property var dragBlockers: {
        if (!root.dragOver || root.dragKey === "" || root.dropInto !== "")
            return [];

        var hit = [];
        for (var i = 0; i < root.dragKeys.length; i++) {
            var s = root.dragSpot(root.dragKeys[i]);
            if (s && s.widget >= 0 && hit.indexOf(s.widget) < 0)
                hit.push(s.widget);

        }
        return hit;
    }

    // whether a rectangle in screen pixels would cover an icon, for widgets
    // looking for somewhere to spawn
    function overlapsIcons(x, y, w, h) {
        if (!root.live)
            return false;

        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++) {
            var p = root.placed[keys[i]];
            var cx = root.tileX(p.c);
            var cy = root.tileY(p.r);
            if (x < cx + root.tileW && x + w > cx && y < cy + root.tileH && y + h > cy)
                return true;

        }
        return false;
    }

    function nearestFree(c, r, blocked, taken) {
        var best = -1;
        var bd = 1e9;
        for (var i = 0; i < root.cols * root.rows; i++) {
            if (blocked[i] || taken[i])
                continue;

            var dc = Math.floor(i / root.rows) - c;
            var dr = (i % root.rows) - r;
            // staying in its column reads as stepping aside; jumping across the
            // screen does not. Ties go down the column, the way the grid fills
            var d = dc * dc * 3 + dr * dr + i * 1e-6;
            if (d < bd) {
                bd = d;
                best = i;
            }
        }
        return best;
    }

    function firstFree(blocked, taken) {
        for (var i = 0; i < root.cols * root.rows; i++) {
            if (!blocked[i] && !taken[i])
                return i;

        }
        return -1;
    }

    // first: keys that win their home over anyone else's (the ones just dropped)
    function relayout(first) {
        // nothing is placed before both the folder and the widgets are known,
        // or a fresh desktop would hand out cells a widget is about to cover
        if (!root.live || !root.listed || !Widgets.loaded)
            return ;

        var n = root.cols * root.rows;
        var blocked = root.blockedGrid();
        var taken = new Array(n);
        var homes = root.homes;
        var out = {};
        var rehome = {};
        var later = [];
        var order = root.items.slice();
        if (first && first.length) {
            var pri = {};
            for (var f = 0; f < first.length; f++)
                pri[first[f]] = f + 1;
            order.sort((a, b) => (pri[a.key] || 1e6) - (pri[b.key] || 1e6));
        }
        // whoever can have their own cell gets it
        for (var i = 0; i < order.length; i++) {
            var it = order[i];
            var h = homes[it.key];
            if (h && h[0] < root.cols && h[1] < root.rows) {
                var idx = h[0] * root.rows + h[1];
                if (!blocked[idx] && !taken[idx]) {
                    out[it.key] = {
                        "c": h[0],
                        "r": h[1],
                        "away": false
                    };
                    taken[idx] = true;
                    continue;
                }
            }
            later.push(it);
        }
        // the rest: pushed off by a widget (they keep their home and come back),
        // pushed off by another icon or the grid shrinking (they move for good),
        // or new (they take the first free cell)
        var last = n - 1;
        for (var j = 0; j < later.length; j++) {
            var e = later[j];
            var hh = homes[e.key];
            var spot = -1;
            var away = false;
            if (hh) {
                var hc = Math.min(root.cols - 1, hh[0]);
                var hr = Math.min(root.rows - 1, hh[1]);
                spot = root.nearestFree(hc, hr, blocked, taken);
                away = hh[0] < root.cols && hh[1] < root.rows && blocked[hh[0] * root.rows + hh[1]];
            } else {
                spot = root.firstFree(blocked, taken);
            }
            if (spot < 0) {
                // a full desktop stacks the overflow on the last cell
                spot = last;
                away = true;
            } else {
                taken[spot] = true;
            }
            var sc = Math.floor(spot / root.rows);
            var sr = spot % root.rows;
            out[e.key] = {
                "c": sc,
                "r": sr,
                "away": away
            };
            if (!away)
                rehome[e.key] = [sc, sr];

        }
        root.placed = out;
        var keys = Object.keys(rehome);
        if (keys.length > 0) {
            var nh = Object.assign({}, homes);
            for (var k = 0; k < keys.length; k++)
                nh[keys[k]] = rehome[keys[k]];
            root.homes = nh;
            root.saveHomes();
        }
    }

    function scheduleLayout() {
        layoutTimer.restart();
    }

    // forget the cells of files that are gone, so a new file by the same name
    // starts fresh
    function pruneHomes() {
        var nh = {};
        var dirty = false;
        var keys = Object.keys(root.homes);
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i];
            if (k.indexOf("::") === 0 || root.byKey[k] !== undefined || root.expected[k])
                nh[k] = root.homes[k];
            else
                dirty = true;
        }
        if (dirty) {
            root.homes = nh;
            root.saveHomes();
        }
    }

    // every icon back in the arrange order, from the starting corner
    function arrange() {
        root.homes = ({});
        root.relayout();
    }

    // ---- moving icons ------------------------------------------------------

    // a drop of our own icons: the grabbed one lands on the cell under the
    // pointer and the rest keep their places around it
    function moveTo(keys, grabbed, px, py) {
        var from = root.placed[grabbed];
        if (!from)
            return ;

        var to = root.cellAt(px, py);
        var dc = to.c - from.c;
        var dr = to.r - from.r;
        if (dc === 0 && dr === 0)
            return ;

        var nh = Object.assign({}, root.homes);
        var first = [grabbed];
        for (var i = 0; i < keys.length; i++) {
            var p = root.placed[keys[i]];
            if (!p)
                continue;

            nh[keys[i]] = [Math.max(0, Math.min(root.cols - 1, p.c + dc)), Math.max(0, Math.min(root.rows - 1, p.r + dr))];
            if (keys[i] !== grabbed)
                first.push(keys[i]);

        }
        root.homes = nh;
        root.relayout(first);
        // the dropped ones live where they landed, even if a widget turned them away
        var settled = Object.assign({}, root.homes);
        for (var j = 0; j < first.length; j++) {
            var q = root.placed[first[j]];
            if (q)
                settled[first[j]] = [q.c, q.r];

        }
        root.homes = settled;
        root.saveHomes();
    }

    // names a copy or a move is about to create, with the cell each should take
    // when the folder reports it
    property var expected: ({})

    function expect(names, px, py) {
        var at = root.cellAt(px, py);
        var blocked = root.blockedGrid();
        var taken = new Array(root.cols * root.rows);
        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++)
            taken[root.placed[keys[i]].c * root.rows + root.placed[keys[i]].r] = true;
        var nh = Object.assign({}, root.homes);
        var ex = Object.assign({}, root.expected);
        for (var j = 0; j < names.length; j++) {
            var spot = root.nearestFree(at.c, at.r, blocked, taken);
            if (spot < 0)
                break;

            taken[spot] = true;
            nh[names[j]] = [Math.floor(spot / root.rows), spot % root.rows];
            ex[names[j]] = true;
        }
        root.homes = nh;
        root.expected = ex;
        expectTimer.restart();
    }

    // ---- selection ---------------------------------------------------------

    property var selected: ({})
    property string anchorKey: ""
    readonly property var selectedKeys: Object.keys(root.selected).filter((k) => root.byKey[k] !== undefined)
    // the rubber band from the background layer, drawn over the icons
    property bool banding: false
    property rect band: Qt.rect(0, 0, 0, 0)
    property var bandBase: ({})

    function isSelected(key) {
        return root.selected[key] === true;
    }

    function clearSelection() {
        if (Object.keys(root.selected).length > 0)
            root.selected = ({});

    }

    function selectOnly(key) {
        var s = {};
        s[key] = true;
        root.selected = s;
        root.anchorKey = key;
    }

    function toggle(key) {
        var s = Object.assign({}, root.selected);
        if (s[key])
            delete s[key];
        else
            s[key] = true;
        root.selected = s;
        root.anchorKey = key;
    }

    // shift: everything between the last clicked icon and this one, in grid order
    function selectRange(key) {
        var a = root.placed[root.anchorKey];
        var b = root.placed[key];
        if (!a || !b) {
            root.selectOnly(key);
            return ;
        }
        var ia = a.c * root.rows + a.r;
        var ib = b.c * root.rows + b.r;
        var lo = Math.min(ia, ib);
        var hi = Math.max(ia, ib);
        var s = {};
        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++) {
            var p = root.placed[keys[i]];
            var idx = p.c * root.rows + p.r;
            if (idx >= lo && idx <= hi)
                s[keys[i]] = true;

        }
        root.selected = s;
    }

    function selectAll() {
        var s = {};
        for (var i = 0; i < root.items.length; i++)
            s[root.items[i].key] = true;
        root.selected = s;
    }

    function beginBand(additive) {
        root.bandBase = additive ? Object.assign({}, root.selected) : ({});
        if (!additive)
            root.clearSelection();

        root.banding = true;
    }

    // an icon is in the band once the band touches its picture or its name
    function updateBand(x, y, w, h) {
        root.band = Qt.rect(x, y, w, h);
        var s = Object.assign({}, root.bandBase);
        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++) {
            var p = root.placed[keys[i]];
            var cx = root.tileX(p.c) + 8;
            var cy = root.tileY(p.r) + 4;
            if (x < cx + root.tileW - 16 && x + w > cx && y < cy + root.tileH - 8 && y + h > cy)
                s[keys[i]] = true;

        }
        root.selected = s;
    }

    function endBand() {
        root.banding = false;
    }

    // ---- what the icons do -------------------------------------------------

    // the icon the pointer grabbed for a system drag, and everything going with it
    property string dragKey: ""
    property var dragKeys: []
    // where a drag over the desktop would land: the cell, or the icon it would go into
    property bool dragOver: false
    property real dragX: 0
    property real dragY: 0
    property string dropInto: ""
    // the key just opened, for a little bounce
    property string launched: ""
    property int launchTick: 0
    // the icon whose name is being edited
    property string renaming: ""
    property string pendingRename: ""
    property bool canPaste: false

    // ---- arrivals and a quick look -----------------------------------------

    // every name the folder has shown, and the ones that showed up after the
    // first listing (a download finishing, a screenshot, a drop): those land
    // with a little bounce. A rename of our own is not an arrival
    property var known: ({})
    property var arrivals: ({})
    property var quiet: ({})
    // a stand-in for a delegate whose row has just gone
    readonly property var emptyItem: ({
        "key": "",
        "name": "",
        "label": "",
        "kind": "file",
        "path": "",
        "uri": "",
        "mime": "",
        "icons": [],
        "thumb": "",
        "exec": false,
        "link": false,
        "mtime": 0,
        "size": 0
    })

    function noteArrivals(list) {
        var now = {};
        var fresh = {};
        for (var i = 0; i < list.length; i++) {
            var n = list[i].name;
            now[n] = true;
            if (root.listed && root.known[n] === undefined && !root.quiet[n])
                fresh[n] = true;

        }
        root.known = now;
        root.arrivals = fresh;
        root.quiet = ({});
    }

    // Space on an icon: the file, large, grown out of its icon
    property string lookKey: ""

    function quickLook(key) {
        var it = root.byKey[key];
        if (!it || it.kind === "home" || it.kind === "trash" || it.kind === "app")
            return ;

        root.lookKey = key;
    }

    function closeLook() {
        root.lookKey = "";
    }

    // the next file in grid order, either way, for the arrow keys
    function lookStep(dir) {
        var keys = Object.keys(root.placed).filter((k) => {
            var it = root.byKey[k];
            return it && it.kind !== "home" && it.kind !== "trash" && it.kind !== "app";
        });
        keys.sort((a, b) => {
            var p = root.placed[a];
            var q = root.placed[b];
            return (p.c * root.rows + p.r) - (q.c * root.rows + q.r);
        });
        var i = keys.indexOf(root.lookKey);
        if (i < 0 || keys.length === 0)
            return ;

        var next = keys[(i + dir + keys.length) % keys.length];
        root.lookKey = next;
        root.selectOnly(next);
    }

    signal menuRequested(real x, real y, var actions)

    // ---- dragging ----------------------------------------------------------

    // what a drag of the selection carries: the files for any app that takes
    // them, and the keys, so a drop back on the desktop knows they are ours
    function dragData() {
        var f = root.filesOf(root.selectedKeys);
        var d = {
            "application/x-lucid-desktop-icons": root.selectedKeys.join("\n")
        };
        if (f.length > 0)
            d["text/uri-list"] = f.map((e) => e.uri).join("\r\n") + "\r\n";

        return d;
    }

    function endDrag() {
        root.dragKey = "";
        root.dragKeys = [];
        root.leaveDrag();
    }

    function leaveDrag() {
        root.dragOver = false;
        root.dropInto = "";
    }

    // which icon a drop at this point would go into: a folder, the trash, or a
    // launcher that can open it; "" means it lands on the desktop itself
    function targetAt(px, py) {
        var cell = root.cellAt(px, py);
        var cx = root.cellX(cell.c);
        var cy = root.cellY(cell.r);
        if (px < cx || px > cx + root.cellW || py < cy || py > cy + root.cellH)
            return "";

        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++) {
            var p = root.placed[keys[i]];
            if (p.c !== cell.c || p.r !== cell.r || root.dragKeys.indexOf(keys[i]) >= 0)
                continue;

            var it = root.byKey[keys[i]];
            if (it && (it.kind === "dir" || it.kind === "home" || it.kind === "trash" || (it.kind === "app" && it.exec)))
                return keys[i];

        }
        return "";
    }

    function hover(px, py) {
        root.dragOver = true;
        root.dragX = px;
        root.dragY = py;
        root.dropInto = root.targetAt(px, py);
    }

    // a drop on either desktop layer. Wayland reports the drop at the middle of
    // the surface, so the point is the last one the drag moved through
    function dropped(drop) {
        var px = root.dragX;
        var py = root.dragY;
        var into = root.targetAt(px, py);
        var ours = root.dragKey !== "";
        var uris = drop.hasUrls ? drop.urls.map((u) => String(u)) : [];
        var target = into ? root.byKey[into] : null;
        if (ours && !target)
            root.moveTo(root.dragKeys, root.dragKey, px, py);
        else if (target && target.kind === "trash")
            root.trashUris(uris);
        else if (target && target.kind === "app")
            root.openWith(into, uris);
        else if (target)
            root.put(ours ? "move" : "auto", uris, into, px, py);
        else
            root.put("auto", uris, "", px, py);
        root.leaveDrag();
        drop.accept(ours ? Qt.MoveAction : Qt.CopyAction);
    }

    function run(cmd) {
        Quickshell.execDetached(cmd);
    }

    function selectionItems() {
        return root.selectedKeys.map((k) => root.byKey[k]);
    }

    function open(key) {
        var it = root.byKey[key];
        if (!it)
            return ;

        if (it.kind === "app" && !it.exec) {
            // an untrusted launcher asks first
            root.openMenu([key], root.tileX(root.placed[key].c) + root.tileW / 2, root.tileY(root.placed[key].r) + root.tileH / 2);
            return ;
        }
        root.launched = key;
        root.launchTick++;
        if (it.kind === "app")
            root.run(["gio", "launch", it.path]);
        else if (it.kind === "trash")
            root.run(["python3", root.script, "open-trash"]);
        else
            root.run(["gio", "open", it.uri]);
    }

    function openSelection() {
        var keys = root.selectedKeys;
        for (var i = 0; i < keys.length; i++)
            root.open(keys[i]);
    }

    function filesOf(keys) {
        var out = [];
        for (var i = 0; i < keys.length; i++) {
            var it = root.byKey[keys[i]];
            if (it && it.kind !== "home" && it.kind !== "trash")
                out.push(it);

        }
        return out;
    }

    function trash(keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        root.run(["gio", "trash", "--"].concat(f.map((e) => e.path)));
        root.clearSelection();
    }

    function copy(keys) {
        var f = root.filesOf(keys);
        if (f.length > 0)
            root.run(["wl-copy", "--type", "text/uri-list", f.map((e) => e.uri).join("\r\n") + "\r\n"]);

    }

    function copyPath(keys) {
        var f = root.filesOf(keys);
        if (f.length > 0)
            root.run(["wl-copy", "--", f.map((e) => e.path).join("\n")]);

    }

    // where the last right-click on the empty desktop landed, for new and pasted things
    property real menuX: 0
    property real menuY: 0

    function newFolder() {
        newFolderProc.running = true;
    }

    function probePaste() {
        if (!pasteProbe.running)
            pasteProbe.running = true;

    }

    function paste() {
        pasteRead.running = true;
    }

    // dropped from outside, or pasted: into the desktop (where the pointer is),
    // or into a folder on it
    function put(mode, uris, intoKey, px, py) {
        if (uris.length === 0)
            return ;

        var into = intoKey ? root.byKey[intoKey] : null;
        var dest = into && (into.kind === "dir" || into.kind === "home") ? into.path : "";
        if (!dest) {
            // a name the desktop already has keeps its icon where it is; the
            // copy's new name ("photo (2).png") gets the cell once it is known
            var names = [];
            for (var i = 0; i < uris.length; i++) {
                var n = root.baseOf(String(uris[i]));
                if (!root.byKey[n])
                    names.push(n);

            }
            root.expect(names, px, py);
        }
        var p = putProc.createObject(root, {
            "placeAt": Qt.point(px, py),
            "intoDesktop": dest === ""
        });
        p.command = ["python3", root.script, "put", mode, dest].concat(uris.map((x) => String(x)));
        p.running = true;
    }

    function baseOf(uri) {
        var tail = uri.substring(uri.lastIndexOf("/") + 1);
        try {
            return decodeURIComponent(tail);
        } catch (e) {
            return tail;
        }
    }

    // a drop on an application's launcher opens the files with it
    function openWith(appKey, uris) {
        var app = root.byKey[appKey];
        if (app && app.kind === "app" && app.exec)
            root.run(["gio", "launch", app.path].concat(uris.map((x) => {
                var s = String(x);
                return s.indexOf("file://") === 0 ? decodeURIComponent(s.substring(7)) : s;
            })));

    }

    function trashUris(uris) {
        root.run(["gio", "trash", "--"].concat(uris.map((x) => String(x))));
    }

    function rename(key, name) {
        var it = root.byKey[key];
        root.renaming = "";
        if (!it || name.trim() === "" || name === it.label || it.kind === "home" || it.kind === "trash")
            return ;

        // the new name takes the old one's cell
        if (it.kind !== "app" && root.homes[key]) {
            var nh = Object.assign({}, root.homes);
            nh[name.trim()] = nh[key];
            root.homes = nh;
            var ex = Object.assign({}, root.expected);
            ex[name.trim()] = true;
            root.expected = ex;
            expectTimer.restart();
            if (root.isSelected(key))
                root.selectOnly(name.trim());

        }
        var qn = Object.assign({}, root.quiet);
        qn[name.trim()] = true;
        root.quiet = qn;
        root.run(["python3", root.script, "rename", it.path, name]);
    }

    function addApp(desktopId) {
        root.run(["python3", root.script, "add-app", desktopId]);
    }

    // every app with a desktop entry, for the picker in Settings
    function installedApps() {
        var out = [];
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e.noDisplay)
                continue;

            out.push({
                "id": e.id,
                "name": e.name || e.id,
                "icon": e.icon ? Quickshell.iconPath(e.icon, true) : "",
                "note": e.genericName || e.comment || ""
            });
        }
        out.sort((a, b) => a.name.localeCompare(b.name));
        return out;
    }

    // paired devices that take files over bluetooth: the last one sent to,
    // then the connected ones, then by name
    function btTargets() {
        if (!Bt.on || !Bt.adapter.devices)
            return [];

        var rank = (d) => (d.address === Bt.lastSendTarget ? 2 : 0) + (d.connected ? 1 : 0);
        var out = Bt.adapter.devices.values.filter((d) => d.paired && Bt.canReceiveFiles(d.address));
        out.sort((a, b) => (rank(b) - rank(a)) || (a.name || "").localeCompare(b.name || ""));
        return out.map((d) => {
            var icon = (d.icon || "").toLowerCase();
            var notes = [];
            if (d.address === Bt.lastSendTarget)
                notes.push("Last used");

            if (d.connected)
                notes.push("Connected");

            return {
                "address": d.address,
                "name": d.name || d.address,
                "note": notes.join(" · "),
                "glyph": icon.indexOf("phone") >= 0 || icon.indexOf("tablet") >= 0 ? root.glyphs.phone : (icon.indexOf("computer") >= 0 ? root.glyphs.computer : root.glyphs.bluetooth)
            };
        });
    }

    // the right-click menu for the icons under the pointer
    function openMenu(keys, px, py) {
        var acts = [];
        var items = keys.map((k) => root.byKey[k]).filter((x) => x !== undefined);
        if (items.length === 0)
            return ;

        var one = items.length === 1 ? items[0] : null;
        var files = root.filesOf(keys);
        if (one && one.kind === "app" && !one.exec) {
            acts.push({
                "id": "icon:trust",
                "label": "Allow Launching",
                "glyph": root.glyphs.shield,
                "divider": false
            });
        } else {
            acts.push({
                "id": "icon:open",
                "label": one ? (one.kind === "app" ? "Launch" : "Open") : "Open " + items.length + " Items",
                "glyph": one && one.kind === "app" ? root.glyphs.play : root.glyphs.open,
                "divider": false
            });
        }
        if (one && one.kind === "trash") {
            if (root.trashCount > 0)
                acts.push({
                "id": "icon:empty",
                "label": "Empty Trash",
                "glyph": root.glyphs.trash,
                "divider": true
            });

        }
        if (one && files.length === 1)
            acts.push({
            "id": "icon:rename",
            "label": "Rename…",
            "glyph": root.glyphs.edit,
            "divider": false
        });

        if (files.length > 0) {
            acts.push({
                "id": "icon:copy",
                "label": "Copy",
                "glyph": root.glyphs.copy,
                "divider": true
            });
            acts.push({
                "id": "icon:path",
                "label": files.length > 1 ? "Copy Paths" : "Copy Path",
                "glyph": root.glyphs.link,
                "divider": false
            });
            acts.push({
                "id": "icon:trash",
                "label": "Move to Trash",
                "glyph": root.glyphs.trash,
                "divider": true
            });
        }
        // plain files only: object push carries no folders. One entry, the
        // devices in its side panel, however many are paired
        var sendable = files.filter((f) => f.kind === "file");
        var targets = sendable.length > 0 ? root.btTargets() : [];
        if (targets.length > 0)
            acts.push({
            "id": "icon:bt",
            "label": "Send via Bluetooth",
            "glyph": root.glyphs.bluetooth,
            "divider": true,
            "children": targets.map((d) => ({
                "id": "icon:bt:" + d.address,
                "label": d.name,
                "note": d.note,
                "glyph": d.glyph
            }))
        });

        root.menuRequested(px, py, acts);
    }

    function runAction(id) {
        var keys = root.selectedKeys;
        if (id === "icon:open") {
            root.openSelection();
        } else if (id === "icon:trust") {
            var t = root.byKey[keys[0]];
            if (t)
                root.run(["python3", root.script, "trust", t.path]);

        } else if (id === "icon:empty") {
            root.run(["gio", "trash", "--empty"]);
        } else if (id === "icon:rename") {
            root.renaming = keys[0] || "";
        } else if (id === "icon:copy") {
            root.copy(keys);
        } else if (id === "icon:path") {
            root.copyPath(keys);
        } else if (id === "icon:trash") {
            root.trash(keys);
        } else if (id.indexOf("icon:bt:") === 0) {
            var addr = id.slice(8);
            var dev = Bt.deviceAt(addr);
            var paths = root.filesOf(keys).filter((f) => f.kind === "file").map((f) => f.path);
            if (paths.length > 0)
                Bt.sendFiles(addr, dev ? dev.name : "", paths);

        } else if (id === "newFolder") {
            root.newFolder();
        } else if (id === "paste") {
            root.paste();
        } else if (id === "arrange") {
            root.arrange();
        } else if (id === "openDesktop") {
            root.run(["gio", "open", "file://" + root.dir]);
        }
    }

    // 24-unit paths for the menus, the same set the dock's icons come from
    readonly property var glyphs: ({
        "open": "M19 19H5V5h7V3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7h-2v7ZM14 3v2h3.59l-9.83 9.83 1.41 1.41L19 6.41V10h2V3h-7Z",
        "play": "M8 5v14l11-7L8 5Z",
        "edit": "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25ZM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83Z",
        "copy": "M16 1H4a2 2 0 0 0-2 2v14h2V3h12V1Zm3 4H8a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h11a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2Zm0 16H8V7h11v14Z",
        "link": "M3.9 12a3.1 3.1 0 0 1 3.1-3.1h4V7H7a5 5 0 0 0 0 10h4v-1.9H7A3.1 3.1 0 0 1 3.9 12ZM8 13h8v-2H8v2Zm9-6h-4v1.9h4a3.1 3.1 0 0 1 0 6.2h-4V17h4a5 5 0 0 0 0-10Z",
        "trash": "M6 19a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V7H6v12ZM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4Z",
        "shield": "M12 1 3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4Zm-2 16-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8Z",
        "newFolder": "M20 6h-8l-2-2H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2Zm-1 8h-3v3h-2v-3h-3v-2h3V9h2v3h3v2Z",
        "paste": "M19 2h-4.18A3 3 0 0 0 12 0a3 3 0 0 0-2.82 2H5a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2Zm-7 0a1 1 0 1 1 0 2 1 1 0 0 1 0-2Zm7 18H5V4h2v3h10V4h2v16Z",
        "arrange": "M3 18h6v-2H3v2ZM3 6v2h18V6H3Zm0 7h12v-2H3v2Z",
        "folder": "M10 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-8l-2-2Z",
        "file": "M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6Zm-1 7V3.5L18.5 9H13Z",
        "home": "M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8h5Z",
        "phone": "M17 1.01 7 1c-1.1 0-2 .9-2 2v18c0 1.1.9 2 2 2h10c1.1 0 2-.9 2-2V3c0-1.1-.9-1.99-2-1.99ZM17 19H7V5h10v14Z",
        "computer": "M20 18c1.1 0 1.99-.9 1.99-2L22 6c0-1.1-.9-2-2-2H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2H0v2h24v-2h-4ZM4 6h16v10H4V6Z",
        "bluetooth": "M17.71 7.71 12 2h-1v7.59L6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 11 14.41V22h1l5.71-5.71-4.3-4.29 4.3-4.29ZM13 5.83l1.88 1.88L13 9.59V5.83Zm1.88 10.46L13 18.17v-3.76l1.88 1.88Z"
    })

    // ---- plumbing ----------------------------------------------------------

    function saveHomes() {
        store.homes = root.homes;
    }

    onItemsChanged: root.scheduleLayout()
    onColsChanged: root.scheduleLayout()
    onRowsChanged: root.scheduleLayout()
    onFromRightChanged: root.scheduleLayout()
    onLiveChanged: {
        root.restartWatcher();
        if (root.live && root.lumaFor === "")
            root.measureWallpaper(wallFile.text().trim());

        if (root.live) {
            root.collectWidgets();
            root.scheduleLayout();
        } else {
            root.clearSelection();
            root.renaming = "";
        }
    }

    Connections {
        function onCountChanged() {
            widgetTimer.restart();
        }

        function onDataChanged() {
            widgetTimer.restart();
        }

        target: Widgets.model
        enabled: root.live
    }

    Connections {
        function onLoadedChanged() {
            widgetTimer.restart();
        }

        function onLiveRectChanged() {
            widgetTimer.restart();
        }

        function onLiveUidChanged() {
            widgetTimer.restart();
        }

        target: Widgets
        enabled: root.live
    }

    Connections {
        function onWidgetsEnabledChanged() {
            widgetTimer.restart();
        }

        target: Prefs
        enabled: root.live
    }

    Timer {
        id: widgetTimer

        // a frame's worth: a drag reports far more often than icons need to move
        interval: 16
        onTriggered: {
            root.collectWidgets();
            root.relayout();
        }
    }

    Timer {
        id: layoutTimer

        interval: 1
        onTriggered: root.relayout()
    }

    // a name that never shows up (a failed copy) stops being reserved
    Timer {
        id: expectTimer

        interval: 8000
        onTriggered: {
            root.expected = ({});
            root.pruneHomes();
        }
    }

    Process {
        id: watcher

        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var d;
                try {
                    d = JSON.parse(line);
                } catch (e) {
                    return ;
                }
                root.dir = d.dir;
                root.dirExists = d.exists;
                root.trashCount = d.trash;
                root.noteArrivals(d.items);
                root.files = d.items;
                root.listed = true;
                root.pruneHomes();
                if (root.pendingRename !== "" && root.byKey[root.pendingRename] !== undefined) {
                    root.selectOnly(root.pendingRename);
                    root.renaming = root.pendingRename;
                    root.pendingRename = "";
                }
            }
        }
    }

    // the watcher's arguments are read when it starts, so set them first
    function restartWatcher() {
        watcher.running = false;
        if (!root.live)
            return ;

        watcher.command = ["python3", root.script, "watch"].concat(Prefs.desktopIconsHidden ? ["--hidden"] : []);
        watcher.running = true;
    }

    Connections {
        function onDesktopIconsHiddenChanged() {
            root.restartWatcher();
        }

        target: Prefs
    }

    Component.onCompleted: {
        root.homes = store.homes || ({});
        root.restartWatcher();
    }

    Process {
        id: newFolderProc

        command: ["python3", root.script, "new-folder"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim();
                if (name === "")
                    return ;

                root.expect([name], root.menuX, root.menuY);
                root.pendingRename = name;
            }
        }
    }

    Process {
        id: pasteProbe

        command: ["wl-paste", "--list-types"]
        stdout: StdioCollector {
            onStreamFinished: root.canPaste = text.split("\n").indexOf("text/uri-list") >= 0
        }
    }

    Process {
        id: pasteRead

        command: ["wl-paste", "--no-newline", "--type", "text/uri-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var uris = text.split(/\r?\n/).filter((u) => u !== "" && u.charAt(0) !== "#");
                root.put("copy", uris, "", root.menuX, root.menuY);
            }
        }
    }

    // one per copy or move, so two drops in a row never share a process
    Component {
        id: putProc

        Process {
            id: proc

            property point placeAt
            property bool intoDesktop: true

            stdout: SplitParser {
                // a name that had to change ("photo (2).png") takes the cell the
                // old one was promised
                onRead: (line) => {
                    var tab = line.indexOf("\t");
                    if (tab < 0 || !proc.intoDesktop)
                        return ;

                    var uri = line.substring(0, tab);
                    var name = line.substring(tab + 1);
                    var asked = root.baseOf(uri);
                    if (name === asked || root.homes[name])
                        return ;

                    if (root.homes[asked] && !root.byKey[asked]) {
                        var nh = Object.assign({}, root.homes);
                        nh[name] = nh[asked];
                        delete nh[asked];
                        root.homes = nh;
                        var ex = Object.assign({}, root.expected);
                        ex[name] = true;
                        root.expected = ex;
                    } else if (root.byKey[asked]) {
                        // the asked name was an icon already there, which
                        // keeps its cell: the copy takes the drop point
                        root.expect([name], proc.placeAt.x, proc.placeAt.y);
                    }
                }
            }
            onExited: proc.destroy()
        }

    }

    FileView {
        id: storeFile

        path: root.home + "/.config/quickshell/luciddesktop/icons.json"
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoaded: root.homes = store.homes || ({})
        onLoadFailed: (err) => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();

        }

        adapter: JsonAdapter {
            id: store

            property var homes: ({})
        }

    }

}
