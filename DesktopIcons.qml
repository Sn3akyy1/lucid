pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// the files on the desktop and where each one sits. icons keep to a grid and
// remember a cell each; a widget always wins the space, and the icons it covers
// step aside together, keeping their shape, until the widget moves off
Singleton {
    id: root

    // on in Settings, and not put away from the desktop's menu
    readonly property bool live: Prefs.loaded && Prefs.desktopIcons && Prefs.desktopIconsShown
    // put away a moment ago: the board stays up while its icons go
    property bool leaving: false
    // brought back a moment ago: icons made now come in as a wave from their corner
    property bool waking: false
    readonly property bool shown: root.live || root.leaving
    readonly property int wakeStep: Math.round(22 * Theme.motionScale)
    readonly property int stowStep: Math.round(12 * Theme.motionScale)
    readonly property string script: Qt.resolvedUrl("./luciddesktop/desktop-icons.py").toString().replace("file://", "")
    readonly property string home: Quickshell.env("HOME")
    // the set picked in Settings > Environment; the helper asks gsettings when it is blank
    readonly property string themeName: Prefs.envIconTheme

    // what the helper last reported
    property string dir: ""
    property bool dirExists: true
    property var files: []
    property var drives: []
    property var specials: ({})
    property int trashCount: 0
    property bool listed: false

    // ---- what is on show ---------------------------------------------------

    function blank(over) {
        return Object.assign({
            "key": "",
            "name": "",
            "label": "",
            "kind": "file",
            "path": "",
            "uri": "",
            "mime": "",
            "desc": "",
            "icon": "",
            "thumb": "",
            "canThumb": false,
            "size": 0,
            "mtime": 0,
            "link": false,
            "hidden": false,
            "exec": false,
            "tags": [],
            "canEject": false,
            "canUnmount": false
        }, over);
    }

    // the specials first, then the drives, then the folder in the arrange order
    readonly property var items: {
        var out = [];
        if (Prefs.desktopIconsHome)
            out.push(root.blank({
                "key": "::home",
                "label": "Home",
                "kind": "home",
                "path": root.home,
                "uri": "file://" + root.home,
                "mime": "inode/directory",
                "desc": "Your home folder",
                "icon": root.specials.home || ""
            }));

        if (Prefs.desktopIconsTrash)
            out.push(root.blank({
                "key": "::trash",
                "label": "Trash",
                "kind": "trash",
                "uri": "trash:///",
                "desc": root.trashCount > 0 ? (root.trashCount === 1 ? "1 item" : root.trashCount + " items") : "Empty",
                "icon": (root.trashCount > 0 ? root.specials.trashFull : root.specials.trash) || ""
            }));

        if (Prefs.desktopIconsDrives)
            for (var d = 0; d < root.drives.length; d++) {
                var v = root.drives[d];
                out.push(root.blank({
                    "key": v.key,
                    "label": v.label,
                    "kind": "drive",
                    "path": v.path,
                    "uri": v.uri,
                    "mime": "inode/directory",
                    "desc": "Drive",
                    "icon": v.icon || root.specials.drive || "",
                    "canEject": v.canEject,
                    "canUnmount": v.canUnmount
                }));
            }
        var f = root.files.slice();
        f.sort(root.comparer(Prefs.desktopIconsSort));
        for (var i = 0; i < f.length; i++)
            out.push(root.blank(Object.assign({
                "key": f[i].name
            }, f[i])));
        return out;
    }
    readonly property var byKey: {
        var m = {};
        for (var i = 0; i < root.items.length; i++)
            m[root.items[i].key] = root.items[i];
        return m;
    }

    // folders stay first either way round; the rest turn about on the direction
    function comparer(how) {
        var inner = root.orderer(how);
        var dirsFirst = (a, b) => (a.kind === "dir" ? 0 : 1) - (b.kind === "dir" ? 0 : 1);
        if (!Prefs.desktopIconsSortDesc)
            return inner;

        return (a, b) => dirsFirst(a, b) || inner(b, a);
    }

    function orderer(how) {
        var byName = (a, b) => a.label.localeCompare(b.label, undefined, {
            "numeric": true,
            "sensitivity": "base"
        });
        var dirsFirst = (a, b) => (a.kind === "dir" ? 0 : 1) - (b.kind === "dir" ? 0 : 1);
        if (how === "date")
            return (a, b) => dirsFirst(a, b) || (b.mtime - a.mtime) || byName(a, b);

        if (how === "size")
            return (a, b) => dirsFirst(a, b) || (b.size - a.size) || byName(a, b);

        if (how === "type")
            return (a, b) => {
                var da = a.kind === "dir" ? 0 : (a.kind === "app" ? 1 : 2);
                var db = b.kind === "dir" ? 0 : (b.kind === "app" ? 1 : 2);
                return (da - db) || a.mime.localeCompare(b.mime) || byName(a, b);
            };

        return (a, b) => dirsFirst(a, b) || byName(a, b);
    }

    // ---- the grid --------------------------------------------------------------

    readonly property var screen: Monitors.mainScreen
    readonly property real screenW: root.screen ? root.screen.width : 1920
    readonly property real screenH: root.screen ? root.screen.height : 1080
    readonly property real dpr: root.screen && root.screen.devicePixelRatio ? root.screen.devicePixelRatio : 1
    readonly property int iconPx: Theme.dp(Prefs.desktopIconSize === "small" ? 32 : (Prefs.desktopIconSize === "large" ? 64 : 48))
    // one tile's layout, shared by the icon, the rename field and what grows out of it:
    // the well round the picture, then two lines of name
    readonly property int wellPad: Math.round(Math.max(Theme.dp(4), root.iconPx * 0.1))
    readonly property int wellSize: root.iconPx + 2 * root.wellPad
    readonly property int wellTop: Theme.dp(2)
    readonly property int iconTop: root.wellTop + root.wellPad
    readonly property int labelTop: root.wellTop + root.wellSize + Theme.dp(3)
    readonly property int nameLineH: Math.ceil(nameMetrics.height * 1.05)
    // what the spacing setting adds beside and below a tile; compact keeps names to one
    // line at rest (the whole name still shows under the pointer and when selected)
    readonly property var spacing: ({
        "compact": [Theme.dp(18), Theme.dp(4)],
        "normal": [Theme.dp(26), Theme.dp(2)],
        "roomy": [Theme.dp(46), Theme.dp(16)]
    })[Prefs.desktopIconSpacing] || [Theme.dp(26), Theme.dp(2)]
    readonly property int nameLines: Prefs.desktopIconSpacing === "compact" ? 1 : 2
    readonly property real tileW: root.iconPx + root.spacing[0]
    readonly property real tileH: root.labelTop + root.nameLines * root.nameLineH + root.spacing[1]
    // cells are the tiles themselves, packed from the starting corner the way windows does,
    // with whatever is left over past the last column and row
    readonly property real cellW: root.tileW
    readonly property real cellH: root.tileH
    readonly property real pad: Theme.dp(10)
    // the bar's strip and a dock that stays up are never under an icon
    readonly property real reserveTop: Prefs.barEnabled && !Prefs.barBottom ? Prefs.effectiveBarTopMargin + Theme.dp(Prefs.barHeight) : 0
    readonly property real reserveBottom: Widgets.spawnBottom
    readonly property real areaY: root.reserveTop + root.pad
    readonly property int cols: Math.max(1, Math.floor((root.screenW - 2 * root.pad) / root.tileW))
    readonly property int rows: Math.max(1, Math.floor((root.screenH - root.reserveTop - root.reserveBottom - 2 * root.pad) / root.tileH))
    readonly property bool fromRight: Prefs.desktopIconsCorner === "right"

    function cellX(c) {
        return root.fromRight ? root.screenW - root.pad - (c + 1) * root.cellW : root.pad + c * root.cellW;
    }

    function cellY(r) {
        return root.areaY + r * root.cellH;
    }

    // whole pixels: the pitch is fractional, and an icon half a pixel off draws soft
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

    // grid order: down each column, then the next one over
    function orderOf(key) {
        var p = root.placed[key];
        return p ? p.c * root.rows + p.r : 1e9;
    }

    function inGridOrder(keys) {
        return keys.slice().sort((a, b) => root.orderOf(a) - root.orderOf(b));
    }

    // ---- names on the wallpaper ------------------------------------------------

    // the wallpaper's lightness (L*, 0-100) on a coarse grid, so a name over a
    // white sky turns dark
    property var luma: ({
        "cols": 0,
        "rows": 0,
        "l": []
    })
    property string lumaFor: ""

    // -1 while unknown
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

    // a name's line, for the tile's height
    FontMetrics {
        id: nameMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelLg
        font.weight: Font.Medium
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

    // a file's name at rest, its extension left off when it is one people know
    function shortLabel(it) {
        if (!it || it.kind !== "file" || !Prefs.desktopIconsHideExt)
            return it ? it.label : "";

        var l = it.label;
        var dot = l.lastIndexOf(".");
        if (dot <= 0 || l.length - dot - 1 > 4)
            return l;

        return l.slice(0, dot);
    }

    property string hoverKey: ""
    // arrow keys draw a focus ring on the icon they are on; a click puts it away
    property bool focusVisible: false

    // colour tags, macos-style, each hue leaning toward the wallpaper's so they sit in the palette
    readonly property var tagNames: ["red", "orange", "yellow", "green", "blue", "purple"]
    readonly property var tagHues: ({
        "red": 4,
        "orange": 28,
        "yellow": 50,
        "green": 140,
        "blue": 212,
        "purple": 282
    })

    function tagColor(name) {
        var h = root.tagHues[name];
        if (h === undefined)
            return Theme.subtext;

        var ph = Theme.cPrimary.hslHue * 360;
        if (ph >= 0) {
            var d = ((ph - h + 540) % 360) - 180;
            h = h + Math.max(-15, Math.min(15, d * 0.5));
        }
        return Theme.atTone(Qt.hsla(((h % 360) + 360) % 360 / 360, 0.75, 0.5, 1), Theme.isLight ? 52 : 72);
    }

    function tagLabel(name) {
        return name.charAt(0).toUpperCase() + name.slice(1);
    }
    // a press puts the tooltip away until the pointer moves to another icon
    property bool tipHold: false

    onHoverKeyChanged: root.tipHold = false

    function human(n) {
        var u = ["bytes", "KB", "MB", "GB", "TB"];
        var i = 0;
        var v = n;
        while (v >= 1000 && i < u.length - 1) {
            v /= 1000;
            i++;
        }
        return i === 0 ? (n === 1 ? "1 byte" : n + " bytes") : v.toFixed(v < 10 ? 1 : 0) + " " + u[i];
    }

    // a file's time the way a file manager says it: today, yesterday, a date
    function when(secs) {
        if (!secs)
            return "";

        var d = new Date(secs * 1000);
        var t = Qt.formatTime(d, Prefs.clock24h ? "HH:mm" : "h:mm AP");
        var now = new Date();
        var day = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (d.getTime() >= day)
            return "Today, " + t;

        if (d.getTime() >= day - 86400000)
            return "Yesterday, " + t;

        return Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy") + ", " + t;
    }

    // ---- where everything sits -------------------------------------------------

    // key -> [c, r]: the cell each icon calls its own, persisted
    property var homes: ({})
    // key -> { c, r, away }: where it is drawn. away = a widget holds its home
    property var placed: ({})
    // the widgets' rectangles on the main screen, padded a little
    property var widgetRects: []
    // the shift each widget's covered icons last stepped aside by, by "w:" + uid
    property var shifts: ({})

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
                    "uid": e.uid,
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

    // which widget rectangle covers a cell, or -1
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

    // the cell under a drag of our own icons, as text, so the plan below is only
    // worked out again when the pointer reaches another cell
    readonly property string dragCell: {
        if (!root.dragOver || root.dragKey === "")
            return "";

        var at = root.cellAt(root.dragX, root.dragY);
        return at.c + "," + at.r;
    }
    // where a drop there puts each dragged icon, planned as the drop itself will:
    // key -> { c, r, widget, lc, lr }, lc/lr being where it lands when a widget holds c, r
    readonly property var dropPlan: {
        if (root.dragCell === "" || root.dropInto !== "")
            return ({});

        var anchor = root.placed[root.dragKey];
        if (!anchor)
            return ({});

        var at = root.dragCell.split(",");
        var dc = Number(at[0]) - anchor.c;
        var dr = Number(at[1]) - anchor.r;
        var homes = Object.assign({}, root.homes);
        var aim = {};
        var first = [root.dragKey];
        for (var i = 0; i < root.dragKeys.length; i++) {
            var k = root.dragKeys[i];
            var p = root.placed[k];
            if (!p)
                continue;

            aim[k] = [Math.max(0, Math.min(root.cols - 1, p.c + dc)), Math.max(0, Math.min(root.rows - 1, p.r + dr))];
            homes[k] = aim[k];
            if (k !== root.dragKey)
                first.push(k);

        }
        var landed = Prefs.desktopIconsAutoArrange || (dc === 0 && dr === 0) ? null : root.plan(homes, first).out;
        var out = {};
        for (var key in aim) {
            var l = landed && landed[key] ? landed[key] : {
                "c": aim[key][0],
                "r": aim[key][1]
            };
            out[key] = {
                "c": aim[key][0],
                "r": aim[key][1],
                "widget": root.widgetOn(aim[key][0], aim[key][1]),
                "lc": l.c,
                "lr": l.r
            };
        }
        return out;
    }

    function dragSpot(key) {
        return root.dropPlan[key] || null;
    }

    // the widgets a drag of our own icons is running into, by index
    readonly property var dragBlockers: {
        if (!root.dragOver || root.dragKey === "" || root.dropInto !== "")
            return [];

        var hit = [];
        for (var k in root.dropPlan) {
            var w = root.dropPlan[k].widget;
            if (w >= 0 && hit.indexOf(w) < 0)
                hit.push(w);

        }
        return hit;
    }

    // for widgets looking for somewhere to spawn
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
            // its own column reads as stepping aside; ties go down the column
            var d = dc * dc * 3 + dr * dr + i * 1e-06;
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

    // a group stepping aside fits at this shift: every cell on the desktop, free, and its own
    function fits(cells, dc, dr, blocked, taken) {
        var seen = {};
        for (var i = 0; i < cells.length; i++) {
            var c = cells[i].c + dc;
            var r = cells[i].r + dr;
            if (c < 0 || r < 0 || c >= root.cols || r >= root.rows)
                return false;

            var idx = c * root.rows + r;
            if (blocked[idx] || taken[idx] || seen[idx])
                return false;

            seen[idx] = true;
        }
        return true;
    }

    // every shift a group could take, nearest first; a tie goes away from the
    // corner the icons fill from, then down
    readonly property var shiftOrder: {
        var out = [];
        for (var dc = 1 - root.cols; dc < root.cols; dc++) {
            for (var dr = 1 - root.rows; dr < root.rows; dr++) {
                if (dc !== 0 || dr !== 0)
                    out.push({
                    "dc": dc,
                    "dr": dr,
                    "d": Math.hypot(dc * root.cellW, dr * root.cellH),
                    "t": (dc < 0 ? 2 : 0) + (dr < 0 ? 1 : 0)
                });

            }
        }
        return out.sort((a, b) => {
            return a.d - b.d || a.t - b.t;
        });
    }

    // the nearest shift the whole group fits at; the last one it took while that
    // still fits and is not much further, so a widget moved about does not set it hopping
    function fitShift(cells, blocked, taken, last) {
        var offs = root.shiftOrder;
        for (var i = 0; i < offs.length; i++) {
            if (!root.fits(cells, offs[i].dc, offs[i].dr, blocked, taken))
                continue;

            if (last && (last.dc !== offs[i].dc || last.dr !== offs[i].dr) && root.fits(cells, last.dc, last.dr, blocked, taken) && Math.hypot(last.dc * root.cellW, last.dr * root.cellH) <= offs[i].d * 1.5 + root.cellW / 2)
                return last;

            return offs[i];
        }
        return null;
    }

    // an icon into a cell; a full desktop stacks the overflow on the last one
    function seat(out, taken, key, spot, away) {
        if (spot < 0) {
            spot = root.cols * root.rows - 1;
            away = true;
        } else {
            taken[spot] = true;
        }
        out[key] = {
            "c": Math.floor(spot / root.rows),
            "r": spot % root.rows,
            "away": away
        };
    }

    // icons that keep a cell to come back to and wait near it: covered by a widget,
    // or past the edge of a grid that shrank. each widget's icons, and those past the
    // edge, step aside as one group, its shape kept; with nowhere to fit as one they
    // take the nearest free cells, handed out in their own order so none swap places.
    // returns the shifts
    function stepAside(list, homes, blocked, taken, out) {
        var groups = {};
        var names = [];
        for (var i = 0; i < list.length; i++) {
            var h = homes[list[i].key];
            var c = Math.min(root.cols - 1, h[0]);
            var r = Math.min(root.rows - 1, h[1]);
            var w = h[0] < root.cols && h[1] < root.rows ? root.widgetOn(c, r) : -1;
            // past the side and past the foot are two groups, far apart
            var g = w >= 0 ? "w:" + root.widgetRects[w].uid : "edge:" + (h[0] >= root.cols ? "c" : "") + (h[1] >= root.rows ? "r" : "");
            if (!groups[g]) {
                groups[g] = [];
                names.push(g);
            }
            groups[g].push({
                "key": list[i].key,
                "c": c,
                "r": r
            });
        }
        var shifts = {};
        for (var k = 0; k < names.length; k++) {
            var cells = groups[names[k]].sort((a, b) => {
                return (a.c * root.rows + a.r) - (b.c * root.rows + b.r);
            });
            var off = root.fitShift(cells, blocked, taken, root.shifts[names[k]] || null);
            if (off) {
                shifts[names[k]] = off;
                for (var m = 0; m < cells.length; m++)
                    root.seat(out, taken, cells[m].key, (cells[m].c + off.dc) * root.rows + cells[m].r + off.dr, true);
                continue;
            }
            var spots = [];
            for (var s = 0; s < cells.length; s++) {
                var spot = root.nearestFree(cells[s].c, cells[s].r, blocked, taken);
                if (spot >= 0)
                    taken[spot] = true;

                spots.push(spot);
            }
            var found = spots.filter((q) => {
                return q >= 0;
            }).sort((a, b) => {
                return a - b;
            });
            var f = 0;
            for (var u = 0; u < cells.length; u++)
                root.seat(out, taken, cells[u].key, spots[u] < 0 ? -1 : found[f++], true);
        }
        return shifts;
    }

    // where every icon goes for these homes: { out: key -> {c, r, away}, rehome:
    // key -> [c, r] for those that move for good, shifts }. first: keys that win
    // their home over anyone else's (the ones just dropped)
    function plan(homes, first) {
        var blocked = root.blockedGrid();
        var taken = new Array(root.cols * root.rows);
        var out = {};
        var rehome = {};
        var later = [];
        var order = root.items.slice();
        if (first && first.length) {
            var pri = {};
            for (var f = 0; f < first.length; f++)
                pri[first[f]] = f + 1;
            order.sort((a, b) => {
                return (pri[a.key] || 1e+06) - (pri[b.key] || 1e+06);
            });
        }
        // whoever can have their own cell gets it
        for (var i = 0; i < order.length; i++) {
            var it = order[i];
            var h = homes[it.key];
            if (h && h[0] < root.cols && h[1] < root.rows) {
                var idx = h[0] * root.rows + h[1];
                if (!blocked[idx] && !taken[idx]) {
                    root.seat(out, taken, it.key, idx, false);
                    continue;
                }
            }
            later.push(it);
        }
        // for good: a new icon takes the first free cell, one whose cell another won the nearest
        var waiting = [];
        for (var j = 0; j < later.length; j++) {
            var e = later[j];
            var hh = homes[e.key];
            if (hh && (hh[0] >= root.cols || hh[1] >= root.rows || blocked[hh[0] * root.rows + hh[1]])) {
                waiting.push(e);
                continue;
            }
            var spot = hh ? root.nearestFree(hh[0], hh[1], blocked, taken) : root.firstFree(blocked, taken);
            root.seat(out, taken, e.key, spot, false);
            if (spot >= 0)
                rehome[e.key] = [out[e.key].c, out[e.key].r];

        }
        return {
            "out": out,
            "rehome": rehome,
            "shifts": root.stepAside(waiting, homes, blocked, taken, out)
        };
    }

    function relayout(first) {
        // nothing is placed before both the folder and the widgets are known
        if (!root.live || !root.listed || !Widgets.loaded)
            return ;

        // auto arrange: every icon in the arrange order, nobody keeps a cell of their own
        var homes = Prefs.desktopIconsAutoArrange ? ({}) : root.homes;
        var p = root.plan(homes, first);
        root.placed = p.out;
        root.shifts = p.shifts;
        var keys = Object.keys(p.rehome);
        if (keys.length > 0 && !Prefs.desktopIconsAutoArrange) {
            var nh = Object.assign({}, homes);
            for (var k = 0; k < keys.length; k++)
                nh[keys[k]] = p.rehome[keys[k]];
            root.homes = nh;
            root.saveHomes();
        }
    }

    function scheduleLayout() {
        layoutTimer.restart();
    }

    // forget the cells of files that are gone, so a new file by the same name starts fresh;
    // home, the trash and drives keep theirs, so a stick plugged in again lands where it was
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
        root.saveHomes();
    }

    function arrangeBy(how) {
        Prefs.desktopIconsSort = how;
        Qt.callLater(root.arrange);
    }

    // ---- moving icons ------------------------------------------------------------

    // a drop of our own: the grabbed one lands under the pointer, the rest keep their places around it
    function moveTo(keys, grabbed, px, py) {
        var from = root.placed[grabbed];
        if (!from || Prefs.desktopIconsAutoArrange)
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

    // names a copy or a move is about to create, and the cell each takes when it shows up
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

    // ---- selection -----------------------------------------------------------------

    property var selected: ({})
    // where a shift range starts, and where the arrow keys are
    property string anchorKey: ""
    property string cursorKey: ""
    readonly property var selectedKeys: Object.keys(root.selected).filter((k) => {
        return root.byKey[k] !== undefined;
    })
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
        root.cursorKey = key;
    }

    function toggle(key) {
        var s = Object.assign({}, root.selected);
        if (s[key])
            delete s[key];
        else
            s[key] = true;
        root.selected = s;
        root.anchorKey = key;
        root.cursorKey = key;
    }

    // shift: everything between the anchor and this one, in grid order
    function selectRange(key) {
        var a = root.placed[root.anchorKey];
        var b = root.placed[key];
        if (!a || !b) {
            root.selectOnly(key);
            return ;
        }
        var lo = Math.min(root.orderOf(root.anchorKey), root.orderOf(key));
        var hi = Math.max(root.orderOf(root.anchorKey), root.orderOf(key));
        var s = {};
        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++) {
            var idx = root.orderOf(keys[i]);
            if (idx >= lo && idx <= hi)
                s[keys[i]] = true;

        }
        root.selected = s;
        root.cursorKey = key;
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
            var cx = root.tileX(p.c) + Theme.dp(10);
            var cy = root.tileY(p.r) + Theme.dp(4);
            if (x < cx + root.tileW - Theme.dp(20) && x + w > cx && y < cy + root.tileH - Theme.dp(8) && y + h > cy)
                s[keys[i]] = true;

        }
        root.selected = s;
    }

    function endBand() {
        root.banding = false;
    }

    // typing a name jumps to it, the way a file manager does
    property string typed: ""

    function typeAhead(ch) {
        root.typed += ch.toLowerCase();
        typedReset.restart();
        var keys = root.inGridOrder(Object.keys(root.placed));
        for (var i = 0; i < keys.length; i++) {
            var it = root.byKey[keys[i]];
            if (it && it.label.toLowerCase().indexOf(root.typed) === 0) {
                root.selectOnly(keys[i]);
                return ;
            }
        }
    }

    Timer {
        id: typedReset

        interval: 900
        onTriggered: root.typed = ""
    }

    // ---- the keyboard ---------------------------------------------------------------

    // the desktop takes the keys only after a click on it, and gives them back
    // the moment a window is focused. an on-demand layer always open for keys
    // would take them from a window whenever the pointer crossed bare desktop
    property bool armed: false
    // bumped to have the layer take focus outright: a click alone hands it over
    // only once the pointer moves again
    property int grabTick: 0
    readonly property bool hasKeys: root.armed && !ToplevelManager.activeToplevel

    // grab only once a click is over: the exclusive pulse makes hyprland let go of
    // every held button, which would cut a drag off at its start
    function arm(grab) {
        if (!root.live)
            return ;

        root.armed = true;
        if (grab === true && ToplevelManager.activeToplevel)
            root.grabTick++;

    }

    // after an overlay of ours (the rename field) gives the keys back to a window
    function armSoon() {
        armTimer.restart();
    }

    Timer {
        id: armTimer

        interval: 220
        onTriggered: root.arm(true)
    }

    Connections {
        function onActiveToplevelChanged() {
            if (ToplevelManager.activeToplevel)
                root.armed = false;

        }

        target: ToplevelManager
    }

    // ---- the desktop's own keys ------------------------------------------------------

    // what the keyboard does on the desktop, remappable in Settings > Keybinds. they act
    // only while the desktop has the keys, so a plain ctrl+c never leaves an app
    readonly property var keyActions: [{
        "id": "open",
        "label": "Open",
        "keys": "Return"
    }, {
        "id": "look",
        "label": "Quick Look",
        "keys": "space"
    }, {
        "id": "info",
        "label": "Get Info",
        "keys": "ALT + Return"
    }, {
        "id": "rename",
        "label": "Rename",
        "keys": "F2"
    }, {
        "id": "cut",
        "label": "Cut",
        "keys": "CTRL + X"
    }, {
        "id": "copy",
        "label": "Copy",
        "keys": "CTRL + C"
    }, {
        "id": "paste",
        "label": "Paste",
        "keys": "CTRL + V"
    }, {
        "id": "copyPath",
        "label": "Copy Path",
        "keys": "CTRL + SHIFT + C"
    }, {
        "id": "duplicate",
        "label": "Duplicate",
        "keys": "CTRL + D"
    }, {
        "id": "trash",
        "label": "Move to Trash",
        "keys": "Delete"
    }, {
        "id": "delete",
        "label": "Delete for Good",
        "keys": "SHIFT + Delete"
    }, {
        "id": "undo",
        "label": "Undo",
        "keys": "CTRL + Z"
    }, {
        "id": "selectAll",
        "label": "Select All",
        "keys": "CTRL + A"
    }, {
        "id": "invert",
        "label": "Invert Selection",
        "keys": "CTRL + I"
    }, {
        "id": "newFolder",
        "label": "New Folder",
        "keys": "CTRL + SHIFT + N"
    }, {
        "id": "newText",
        "label": "New Text Document",
        "keys": "CTRL + ALT + N"
    }, {
        "id": "compress",
        "label": "Compress",
        "keys": ""
    }, {
        "id": "terminal",
        "label": "Open in Terminal",
        "keys": "CTRL + ALT + T"
    }, {
        "id": "hidden",
        "label": "Show Hidden Files",
        "keys": "CTRL + H"
    }, {
        "id": "arrange",
        "label": "Arrange Icons",
        "keys": ""
    }, {
        "id": "refresh",
        "label": "Refresh",
        "keys": "F5"
    }, {
        "id": "hideIcons",
        "label": "Hide Icons",
        "keys": ""
    }]
    // the changes from those, by id: a combo, or "" for none
    readonly property var keyOverrides: {
        try {
            var o = JSON.parse(Prefs.desktopKeys || "{}");
            return o && typeof o === "object" ? o : ({});
        } catch (e) {
            return ({});
        }
    }

    function keyAction(id) {
        for (var i = 0; i < root.keyActions.length; i++) {
            if (root.keyActions[i].id === id)
                return root.keyActions[i];

        }
        return null;
    }

    function keysFor(id) {
        if (root.keyOverrides[id] !== undefined)
            return root.keyOverrides[id];

        var a = root.keyAction(id);
        return a ? a.keys : "";
    }

    // as menus write it: Ctrl+C, Del, Enter
    function keyHint(id) {
        var k = root.keysFor(id);
        return k ? Keybinds.tokens(k).join("+") : "";
    }

    function setKeys(id, keys) {
        var o = Object.assign({}, root.keyOverrides);
        var a = root.keyAction(id);
        if (a && root.normKeys(keys) === root.normKeys(a.keys))
            delete o[id];
        else
            o[id] = keys;
        Prefs.desktopKeys = JSON.stringify(o);
    }

    function resetKeys(id) {
        var o = Object.assign({}, root.keyOverrides);
        delete o[id];
        Prefs.desktopKeys = JSON.stringify(o);
    }

    // modifiers in one order and lower case, so "SHIFT + CTRL + c" is "ctrl+shift+c"
    function normKeys(k) {
        var parts = String(k || "").split("+").map((p) => {
            return p.trim().toLowerCase();
        }).filter((p) => {
            return p !== "";
        });
        if (parts.length === 0)
            return "";

        var order = ["super", "ctrl", "control", "alt", "shift"];
        var mods = parts.filter((p) => {
            return order.indexOf(p) >= 0;
        }).map((p) => {
            return p === "control" ? "ctrl" : p;
        });
        mods.sort((a, b) => {
            return order.indexOf(a) - order.indexOf(b);
        });
        var key = parts.filter((p) => {
            return order.indexOf(p) < 0;
        });
        return mods.concat(key).join("+");
    }

    function actionFor(combo) {
        var n = root.normKeys(combo);
        if (n === "")
            return "";

        for (var i = 0; i < root.keyActions.length; i++) {
            if (root.normKeys(root.keysFor(root.keyActions[i].id)) === n)
                return root.keyActions[i].id;

        }
        return "";
    }

    // another action on the same keys, for settings to warn about
    function clashOf(id) {
        var n = root.normKeys(root.keysFor(id));
        if (n === "")
            return "";

        for (var i = 0; i < root.keyActions.length; i++) {
            var a = root.keyActions[i];
            if (a.id !== id && root.normKeys(root.keysFor(a.id)) === n)
                return a.label;

        }
        return "";
    }

    // where a keyboard paste or a new item lands: the first free cell
    function atStart() {
        root.menuX = root.cellX(0) + 1;
        root.menuY = root.cellY(0) + 1;
    }

    function invertSelection() {
        var s = {};
        root.items.forEach((it) => {
            if (!root.isSelected(it.key))
                s[it.key] = true;

        });
        root.selected = s;
    }

    function doKey(id) {
        var keys = root.selectedKeys;
        var at = root.isSelected(root.cursorKey) ? root.cursorKey : (keys.length > 0 ? keys[0] : "");
        if (id === "open") {
            root.openSelection();
        } else if (id === "look") {
            if (at !== "")
                root.quickLook(at);

        } else if (id === "info") {
            if (at !== "")
                root.getInfo(at);

        } else if (id === "rename") {
            if (keys.length === 1 && root.filesOf(keys).length === 1)
                root.renaming = keys[0];

        } else if (id === "cut") {
            root.cut(keys);
        } else if (id === "copy") {
            root.copy(keys);
        } else if (id === "paste") {
            root.atStart();
            root.paste("");
        } else if (id === "copyPath") {
            root.copyPath(keys);
        } else if (id === "duplicate") {
            root.make("duplicate", keys);
        } else if (id === "trash") {
            root.trash(keys);
        } else if (id === "delete") {
            root.deleteForever(keys);
        } else if (id === "undo") {
            root.undo();
        } else if (id === "selectAll") {
            root.selectAll();
        } else if (id === "invert") {
            root.invertSelection();
        } else if (id === "newFolder") {
            root.atStart();
            root.newItem("folder", "");
        } else if (id === "newText") {
            root.atStart();
            root.newItem("text", "");
        } else if (id === "compress") {
            root.make("compress", keys);
        } else if (id === "terminal") {
            var it = at !== "" ? root.byKey[at] : null;
            root.openTerminal(it && (it.kind === "dir" || it.kind === "home" || it.kind === "drive") ? it.path : (root.dir || root.home + "/Desktop"));
        } else if (id === "hidden") {
            Prefs.desktopIconsHidden = !Prefs.desktopIconsHidden;
        } else if (id === "arrange") {
            root.arrange();
        } else if (id === "refresh") {
            root.restartWatcher();
        } else if (id === "hideIcons") {
            Prefs.desktopIconsShown = false;
        }
    }

    // ---- what the icons do ----------------------------------------------------------

    // the icon the pointer grabbed for a system drag, and everything going with it
    property string dragKey: ""
    property var dragKeys: []
    // where a drag over the desktop would land: the cell, or the icon it would go into
    property bool dragOver: false
    property real dragX: 0
    property real dragY: 0
    property string dropInto: ""
    // what letting go would do, from the modifiers held: "move", "copy" or "link"
    property string dropAction: "move"
    // an app pulled off the dock (or anywhere that speaks this type): it lands as a launcher
    readonly property string appMime: "application/x-lucid-desktop-app"
    property bool dragApp: false
    // the free cell an app being dragged in would take
    readonly property var appSpot: {
        if (!root.dragApp || !root.dragOver)
            return null;

        var at = root.cellAt(root.dragX, root.dragY);
        var taken = new Array(root.cols * root.rows);
        var keys = Object.keys(root.placed);
        for (var i = 0; i < keys.length; i++)
            taken[root.placed[keys[i]].c * root.rows + root.placed[keys[i]].r] = true;
        var spot = root.nearestFree(at.c, at.r, root.blockedGrid(), taken);
        return spot < 0 ? null : {
            "c": Math.floor(spot / root.rows),
            "r": spot % root.rows
        };
    }
    // the key just opened, for a press-in; a folder that just took a drop, for a gulp
    property string launched: ""
    property int launchTick: 0
    property string received: ""
    property int receiveTick: 0
    property string renaming: ""
    property string pendingRename: ""
    // the rename field's padding and size, so the icon's selection wraps it
    readonly property int renamePadH: Theme.dp(8)
    readonly property int renamePadV: Theme.dp(4)
    property real renameW: 0
    property real renameH: 0

    // every name the folder has shown, and the ones that turned up after the
    // first listing (a download, a screenshot, a drop): those pop in
    property var known: ({})
    property var arrivals: ({})
    property var quiet: ({})

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

    // where an icon about to go flies to (the trash, the folder it went into): key -> {x, y}
    property var flyTo: ({})

    function centreOf(key) {
        var p = root.placed[key];
        return p ? {
            "x": root.tileX(p.c) + root.tileW / 2,
            "y": root.tileY(p.r) + root.iconTop + root.iconPx / 2
        } : null;
    }

    function flyAll(keys, target) {
        if (!target)
            return ;

        var m = Object.assign({}, root.flyTo);
        for (var i = 0; i < keys.length; i++)
            m[keys[i]] = target;
        root.flyTo = m;
        flyClear.restart();
    }

    Timer {
        id: flyClear

        interval: 6000
        onTriggered: root.flyTo = ({})
    }

    // ---- quick look and get info ----------------------------------------------------

    property string lookKey: ""

    function canLook(it) {
        return it && (it.kind === "file" || it.kind === "dir");
    }

    function quickLook(key) {
        if (!root.canLook(root.byKey[key]))
            return ;

        root.lookKey = key;
        // the keys stay with the desktop once it closes
        root.armed = true;
    }

    function closeLook() {
        root.lookKey = "";
    }

    function lookStep(dir) {
        var keys = root.inGridOrder(Object.keys(root.placed).filter((k) => {
            return root.canLook(root.byKey[k]);
        }));
        var i = keys.indexOf(root.lookKey);
        if (i < 0 || keys.length === 0)
            return ;

        var next = keys[(i + dir + keys.length) % keys.length];
        root.lookKey = next;
        root.selectOnly(next);
    }

    // the sheet a file's details show on, and what the helper read for it
    property string infoKey: ""
    property var info: null

    function getInfo(key) {
        var it = root.byKey[key];
        if (!it || it.path === "")
            return ;

        root.closeLook();
        root.infoKey = key;
        root.info = null;
        root.armed = true;
        infoProc.running = false;
        infoProc.command = ["python3", root.script, "info", it.path];
        infoProc.running = true;
    }

    function closeInfo() {
        root.infoKey = "";
        infoProc.running = false;
    }

    // a file allowed to run as a program, or not
    function setExecutable(key, on) {
        var it = root.byKey[key];
        if (!it || it.path === "")
            return ;

        chmodProc.command = ["chmod", on ? "u+x" : "u-x", "--", it.path];
        chmodProc.running = true;
    }

    // what a folder holds, for its tooltip and quick look: path -> { count, items }
    property var peeks: ({})

    function peek(path) {
        if (path === "" || root.peeks[path] !== undefined)
            return ;

        var m = Object.assign({}, root.peeks);
        m[path] = null;
        root.peeks = m;
        var p = peekProc.createObject(root, {
            "dir": path
        });
        p.command = ["python3", root.script, "peek", path].concat(root.themeArgs(Theme.dp(48)));
        p.running = true;
    }

    // a folder's contents go stale with any change on the desktop
    onFilesChanged: {
        if (Object.keys(root.peeks).length > 0)
            root.peeks = ({});

    }

    signal menuRequested(real x, real y, var rows)

    // ---- the snackbar and the dialog --------------------------------------------------

    // a line at the foot of the screen after something happened, with undo when it can be
    property var snack: null

    function notify(text, canUndo) {
        root.snack = {
            "text": text,
            "undo": canUndo === true,
            "tick": Date.now()
        };
        snackTimer.restart();
    }

    function dropSnack() {
        snackTimer.stop();
        root.snack = null;
    }

    Timer {
        id: snackTimer

        interval: 6000
        onTriggered: root.snack = null
    }

    // a question before something that cannot be taken back: {icon, title, body, confirm, action}
    property var dialog: null

    function ask(icon, title, body, confirm, action) {
        root.dialog = {
            "icon": icon,
            "title": title,
            "body": body,
            "confirm": confirm,
            "action": action
        };
    }

    function answer(ok) {
        var d = root.dialog;
        root.dialog = null;
        if (!ok || !d)
            return ;

        if (d.action.op === "delete") {
            root.flyAll(d.action.keys, null);
            root.run(["python3", root.script, "delete"].concat(d.action.paths));
            root.notify(d.action.paths.length === 1 ? "Deleted “" + d.action.name + "”" : "Deleted " + d.action.paths.length + " items", false);
            root.clearSelection();
        } else if (d.action.op === "empty") {
            root.run(["gio", "trash", "--empty"]);
            root.notify("Emptied the Trash", false);
        }
    }

    // ---- undo -------------------------------------------------------------------------

    // newest last: {label, kind, ...}. trash -> paths; relocate -> pairs [now, before];
    // created -> paths; rename -> dir, from, to; tags -> before {path: tags}
    property var undoStack: []
    readonly property var lastUndo: root.undoStack.length > 0 ? root.undoStack[root.undoStack.length - 1] : null

    function pushUndo(op) {
        var s = root.undoStack.slice(-19);
        s.push(op);
        root.undoStack = s;
    }

    function undo() {
        var op = root.lastUndo;
        if (!op)
            return ;

        root.undoStack = root.undoStack.slice(0, -1);
        root.dropSnack();
        if (op.kind === "trash") {
            root.run(["python3", root.script, "restore", "--tags", JSON.stringify(op.tags || ({}))].concat(op.paths));
            if (op.tags && Object.keys(op.tags).length > 0)
                refreshTimer.restart();

        } else if (op.kind === "relocate") {
            var args = [];
            for (var i = 0; i < op.pairs.length; i++)
                args.push(op.pairs[i][0], op.pairs[i][1]);
            root.run(["python3", root.script, "relocate"].concat(args));
        } else if (op.kind === "created") {
            root.run(["gio", "trash", "--"].concat(op.paths));
        } else if (op.kind === "rename") {
            var q = Object.assign({}, root.quiet);
            q[op.from] = true;
            root.quiet = q;
            if (root.homes[op.to]) {
                var nh = Object.assign({}, root.homes);
                nh[op.from] = nh[op.to];
                root.homes = nh;
            }
            root.run(["python3", root.script, "rename", op.dir + "/" + op.to, op.from]);
        } else if (op.kind === "tags") {
            var paths = Object.keys(op.before);
            for (var j = 0; j < paths.length; j++)
                root.run(["python3", root.script, "set-tags", op.before[paths[j]].join(","), paths[j]]);
            refreshTimer.restart();
        }
    }

    // ---- file actions ----------------------------------------------------------------------

    function run(cmd) {
        Quickshell.execDetached(cmd);
    }

    function open(key) {
        var it = root.byKey[key];
        if (!it)
            return ;

        if (it.kind === "app" && !it.exec) {
            // a launcher nobody has allowed yet asks first
            var c = root.centreOf(key);
            if (c)
                root.openMenu([key], c.x, c.y);

            return ;
        }
        root.launched = key;
        root.launchTick++;
        if (it.kind === "app")
            root.run(["gio", "launch", it.path]);
        else if (it.kind === "trash")
            root.run(["python3", root.script, "open-trash"]);
        else
            root.run(["python3", root.script, "open", it.uri]);
    }

    function openSelection() {
        var keys = root.selectedKeys;
        for (var i = 0; i < keys.length; i++)
            root.open(keys[i]);
    }

    // what a copy, the trash or a drag can carry: never home, the trash or a drive
    function filesOf(keys) {
        var out = [];
        for (var i = 0; i < keys.length; i++) {
            var it = root.byKey[keys[i]];
            if (it && (it.kind === "file" || it.kind === "dir" || it.kind === "app"))
                out.push(it);

        }
        return out;
    }

    function pathsOf(items) {
        return items.map((e) => {
            return e.path;
        });
    }

    function named(items, one, many) {
        return items.length === 1 ? one.replace("%1", "“" + items[0].label + "”") : many.replace("%n", items.length);
    }

    function trash(keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        root.flyAll(f.map((e) => {
            return e.key;
        }), root.placed["::trash"] ? root.centreOf("::trash") : null);
        root.run(["gio", "trash", "--"].concat(root.pathsOf(f)));
        var tags = {};
        f.forEach((e) => {
            if (e.tags.length > 0)
                tags[e.path] = e.tags;

        });
        root.pushUndo({
            "label": "Undo Move to Trash",
            "kind": "trash",
            "paths": root.pathsOf(f),
            "tags": tags
        });
        root.notify(root.named(f, "Moved %1 to the Trash", "Moved %n items to the Trash"), true);
        root.clearSelection();
    }

    function deleteForever(keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        root.ask("delete_forever", f.length === 1 ? "Delete “" + f[0].label + "” for good?" : "Delete " + f.length + " items for good?", "They skip the Trash, and this can't be undone.", "Delete", {
            "op": "delete",
            "paths": root.pathsOf(f),
            "keys": f.map((e) => {
                return e.key;
            }),
            "name": f[0].label
        });
    }

    function emptyTrash() {
        if (root.trashCount === 0)
            return ;

        root.ask("delete_sweep", "Empty the Trash?", (root.trashCount === 1 ? "The item in it is" : "All " + root.trashCount + " items in it are") + " deleted for good. This can't be undone.", "Empty Trash", {
            "op": "empty"
        });
    }

    function copyPath(keys) {
        var f = root.filesOf(keys);
        if (f.length > 0)
            root.run(["wl-copy", "--", root.pathsOf(f).join("\n")]);

    }

    function isArchive(it) {
        return it && it.kind === "file" && /zip|tar|rar|7z|compressed|x-xz|x-bzip|gzip|zstd|java-archive|x-cpio|iso9660/.test(it.mime);
    }

    function openTerminal(dir) {
        root.run(["xdg-terminal-exec", "--dir=" + dir]);
    }

    // a copy into one of the home folders (documents, downloads...), from send to
    function sendTo(dest, label, keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        var p = putProc.createObject(root, {
            "placeAt": Qt.point(0, 0),
            "intoDesktop": false,
            "mode": "copy",
            "destDir": dest,
            "destLabel": label
        });
        p.command = ["python3", root.script, "put", "copy", dest].concat(f.map((e) => {
            return e.uri;
        }));
        p.running = true;
    }

    function sendToPhone(id, name, keys) {
        var f = root.filesOf(keys).filter((e) => {
            return e.kind !== "dir";
        });
        if (f.length === 0) {
            root.notify("Folders can't be sent to a phone", false);
            return ;
        }
        KdeConnect.shareFiles(id, f.map((e) => {
            return e.uri;
        }));
        root.notify(root.named(f, "Sending %1 to " + name, "Sending %n files to " + name), false);
    }

    // object push carries files, not folders
    function sendOverBluetooth(address, keys) {
        var f = root.filesOf(keys).filter((e) => {
            return e.kind === "file";
        });
        if (f.length === 0) {
            root.notify("Only files can be sent over Bluetooth", false);
            return ;
        }
        var dev = Bt.deviceAt(address);
        Bt.sendFiles(address, dev ? dev.name : "", f.map((e) => {
            return e.path;
        }));
    }

    // paired devices that take files over bluetooth: the last one sent to, then
    // the connected ones, then by name
    function btTargets() {
        if (!Bt.on || !Bt.adapter.devices)
            return [];

        var rank = (d) => {
            return (d.address === Bt.lastSendTarget ? 2 : 0) + (d.connected ? 1 : 0);
        };
        var out = Bt.adapter.devices.values.filter((d) => {
            return d.paired && Bt.canReceiveFiles(d.address);
        });
        out.sort((a, b) => {
            return (rank(b) - rank(a)) || (a.name || "").localeCompare(b.name || "");
        });
        return out;
    }

    // new things, made at the last right-click (or the first free cell) and named straight away
    function newItem(kind, template) {
        var p = makeProc.createObject(root, {
            "placeAt": Qt.point(root.menuX, root.menuY),
            "what": kind
        });
        p.command = ["python3", root.script, "new", kind].concat(template ? [template] : []);
        p.running = true;
    }

    // duplicate, make link, compress, extract: each prints what it made, which lands beside the source
    function make(op, keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        var c = root.centreOf(f[0].key) || ({
            "x": root.menuX,
            "y": root.menuY
        });
        var p = makeProc.createObject(root, {
            "placeAt": Qt.point(c.x, c.y),
            "what": op
        });
        p.command = ["python3", root.script, op].concat(root.pathsOf(op === "extract" ? [f[0]] : f));
        p.running = true;
        if (op === "compress" || op === "extract")
            root.notify(op === "compress" ? root.named(f, "Compressing %1…", "Compressing %n items…") : "Extracting “" + f[0].label + "”…", false);

    }

    // a tag on every selected file, or off them all if they all wear it
    function toggleTag(tag, keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        var all = f.every((e) => {
            return e.tags.indexOf(tag) >= 0;
        });
        var before = {};
        for (var i = 0; i < f.length; i++) {
            var e = f[i];
            before[e.path] = e.tags.slice();
            var next = e.tags.filter((t) => {
                return t !== tag;
            });
            if (!all)
                next.push(tag);

            next.sort((a, b) => {
                return root.tagNames.indexOf(a) - root.tagNames.indexOf(b);
            });
            root.run(["python3", root.script, "set-tags", next.join(","), e.path]);
        }
        root.pushUndo({
            "label": "Undo Tag",
            "kind": "tags",
            "before": before
        });
        // tags live in gvfs metadata, which the folder watch cannot see change
        refreshTimer.restart();
    }

    function clearTags(keys) {
        var f = root.filesOf(keys).filter((e) => {
            return e.tags.length > 0;
        });
        if (f.length === 0)
            return ;

        var before = {};
        for (var i = 0; i < f.length; i++) {
            before[f[i].path] = f[i].tags.slice();
            root.run(["python3", root.script, "set-tags", "", f[i].path]);
        }
        root.pushUndo({
            "label": "Undo Clear Tags",
            "kind": "tags",
            "before": before
        });
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer

        interval: 450
        onTriggered: root.restartWatcher()
    }

    // ---- the clipboard ---------------------------------------------------------------------

    // what a paste would bring: {mode: copy|cut, uris, image}
    property var clip: ({
        "mode": "copy",
        "uris": [],
        "image": false
    })
    readonly property bool canPaste: root.clip.uris.length > 0 || root.clip.image
    // cut and waiting for a paste: drawn faded, the way file managers show it
    property var cutKeys: ({})
    // a paste asked for before the clipboard was read: {into, x, y}
    property var pendingPaste: null
    // where the last right-click on the empty desktop landed, for new and pasted things
    property real menuX: 0
    property real menuY: 0

    function probePaste() {
        if (!clipProc.running)
            clipProc.running = true;

    }

    function copy(keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        root.cutKeys = ({});
        var uris = f.map((e) => {
            return e.uri;
        });
        root.run(["wl-copy", "--type", "text/uri-list", uris.join("\r\n") + "\r\n"]);
        root.clip = {
            "mode": "copy",
            "uris": uris,
            "image": false
        };
    }

    // nautilus's own type, so a paste in files moves them too
    function cut(keys) {
        var f = root.filesOf(keys);
        if (f.length === 0)
            return ;

        var uris = f.map((e) => {
            return e.uri;
        });
        var m = {};
        f.forEach((e) => {
            m[e.key] = true;
        });
        root.cutKeys = m;
        root.run(["wl-copy", "--type", "x-special/gnome-copied-files", "cut\n" + uris.join("\n")]);
        root.clip = {
            "mode": "cut",
            "uris": uris,
            "image": false
        };
        clipWatchStart.restart();
    }

    function paste(intoKey) {
        root.pendingPaste = {
            "into": intoKey || "",
            "x": root.menuX,
            "y": root.menuY
        };
        clipProc.running = false;
        clipProc.running = true;
    }

    function doPaste() {
        var p = root.pendingPaste;
        root.pendingPaste = null;
        if (!p)
            return ;

        if (root.clip.uris.length > 0) {
            var cut = root.clip.mode === "cut";
            root.put(cut ? "move" : "copy", root.clip.uris, p.into, p.x, p.y);
            if (cut) {
                // a cut is pasted once, as in file managers
                root.cutKeys = ({});
                root.run(["wl-copy", "--clear"]);
                root.clip = {
                    "mode": "copy",
                    "uris": [],
                    "image": false
                };
            }
        } else if (root.clip.image) {
            var into = p.into ? root.byKey[p.into] : null;
            var dest = into ? into.path : "";
            var q = makeProc.createObject(root, {
                "placeAt": Qt.point(p.x, p.y),
                "what": "image",
                "intoDesktop": dest === "",
                "destDir": dest
            });
            q.command = ["python3", root.script, "paste-image", dest];
            q.running = true;
        }
    }

    // dropped from outside or pasted: onto the desktop where the pointer is, or into a folder or drive on it
    function put(mode, uris, intoKey, px, py) {
        if (uris.length === 0)
            return ;

        var into = intoKey ? root.byKey[intoKey] : null;
        var dest = into && (into.kind === "dir" || into.kind === "home" || into.kind === "drive") ? into.path : "";
        if (!dest) {
            // a name the desktop already has keeps its icon where it is; the copy's new name gets the cell once known
            var names = [];
            for (var i = 0; i < uris.length; i++) {
                var n = root.baseOf(String(uris[i]));
                if (!root.byKey[n])
                    names.push(n);

            }
            root.expect(names, px, py);
        } else {
            // what goes in flies into it
            var ours = [];
            for (var j = 0; j < uris.length; j++) {
                var k = root.keyOfUri(String(uris[j]));
                if (k !== "")
                    ours.push(k);

            }
            if (mode === "move" || mode === "auto")
                root.flyAll(ours, root.centreOf(intoKey));

        }
        var p = putProc.createObject(root, {
            "placeAt": Qt.point(px, py),
            "intoDesktop": dest === "",
            "mode": mode,
            "destDir": dest || root.dir,
            "destLabel": into ? into.label : "the Desktop",
            "destKey": intoKey || ""
        });
        p.command = ["python3", root.script, "put", mode, dest].concat(uris.map((x) => {
            return String(x);
        }));
        p.running = true;
    }

    function keyOfUri(uri) {
        for (var i = 0; i < root.files.length; i++) {
            if (root.files[i].uri === uri)
                return root.files[i].name;

        }
        return "";
    }

    function baseOf(uri) {
        var tail = uri.substring(uri.lastIndexOf("/") + 1);
        try {
            return decodeURIComponent(tail);
        } catch (e) {
            return tail;
        }
    }

    function localPaths(uris) {
        return uris.map((x) => {
            var s = String(x);
            return s.indexOf("file://") === 0 ? decodeURIComponent(s.substring(7)) : s;
        });
    }

    // a drop on a launcher opens the files with it
    function openWith(appKey, uris) {
        var app = root.byKey[appKey];
        if (app && app.kind === "app" && app.exec)
            root.run(["gio", "launch", app.path].concat(root.localPaths(uris)));

    }

    function trashUris(uris) {
        if (uris.length === 0)
            return ;

        var paths = root.localPaths(uris);
        root.flyAll(uris.map((u) => {
            return root.keyOfUri(String(u));
        }).filter((k) => {
            return k !== "";
        }), root.centreOf("::trash"));
        root.run(["gio", "trash", "--"].concat(paths));
        root.pushUndo({
            "label": "Undo Move to Trash",
            "kind": "trash",
            "paths": paths
        });
        root.notify(paths.length === 1 ? "Moved “" + root.baseOf(paths[0]) + "” to the Trash" : "Moved " + paths.length + " items to the Trash", true);
    }

    function rename(key, name) {
        var it = root.byKey[key];
        root.renaming = "";
        var nm = name.trim();
        if (!it || nm === "" || nm === it.label || nm.indexOf("/") >= 0 || root.filesOf([key]).length === 0)
            return ;

        // the new name takes the old one's cell
        if (it.kind !== "app" && root.homes[key]) {
            var nh = Object.assign({}, root.homes);
            nh[nm] = nh[key];
            root.homes = nh;
            var ex = Object.assign({}, root.expected);
            ex[nm] = true;
            root.expected = ex;
            expectTimer.restart();
            if (root.isSelected(key))
                root.selectOnly(nm);

        }
        var qn = Object.assign({}, root.quiet);
        qn[nm] = true;
        root.quiet = qn;
        if (it.kind !== "app")
            root.pushUndo({
                "label": "Undo Rename",
                "kind": "rename",
                "dir": root.dir,
                "from": it.name,
                "to": nm
            });

        root.run(["python3", root.script, "rename", it.path, nm]);
    }

    // a dock pin dropped on the desktop: its launcher, or a link to a pinned folder or file
    function addDockApp(d, px, py) {
        if (!d)
            return ;

        var m = /^xdg-open\s+(.+)$/.exec(d.command || "");
        if (m) {
            var path = m[1].trim();
            if (path.charAt(0) === "'")
                path = path.slice(1, -1).split("'\\''").join("'");

            root.put("link", ["file://" + encodeURI(path)], "", px, py);
            return ;
        }
        var p = makeProc.createObject(root, {
            "placeAt": Qt.point(px, py),
            "what": "app"
        });
        p.command = ["python3", root.script, "add-dock-app", d.appId || "", d.iconName || "", d.name || "", d.command || ""];
        p.running = true;
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
        out.sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    // ---- dragging ---------------------------------------------------------------------

    // the files for any app that takes them, and the keys, so a drop back here knows they are ours
    function dragData() {
        var f = root.filesOf(root.selectedKeys);
        var d = {
            "application/x-lucid-desktop-icons": root.selectedKeys.join("\n")
        };
        if (f.length > 0)
            d["text/uri-list"] = f.map((e) => {
                return e.uri;
            }).join("\r\n") + "\r\n";

        return d;
    }

    function endDrag() {
        root.dragKey = "";
        root.dragKeys = [];
        root.leaveDrag();
    }

    function leaveDrag() {
        root.dragOver = false;
        root.dragApp = false;
        root.dropInto = "";
        springTimer.stop();
        root.springKey = "";
    }

    function takesDrops(it) {
        return it && (it.kind === "dir" || it.kind === "home" || it.kind === "trash" || it.kind === "drive" || (it.kind === "app" && it.exec));
    }

    // the icon a drop at this point would go into; "" means the desktop itself
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

            if (root.takesDrops(root.byKey[keys[i]]))
                return keys[i];

        }
        return "";
    }

    function actionOf(qtAction, ours) {
        if (qtAction === Qt.LinkAction)
            return "link";

        if (ours)
            return qtAction === Qt.CopyAction ? "copy" : "move";

        return "auto";
    }

    // a folder held under a drag springs open in the file manager, as on a mac
    property string springKey: ""

    function hover(px, py, qtAction) {
        root.dragOver = true;
        root.dragX = px;
        root.dragY = py;
        root.dropAction = root.dragApp ? "copy" : root.actionOf(qtAction, root.dragKey !== "");
        // an app lands on the desktop itself: nothing lights up under it
        var into = root.dragApp ? "" : root.targetAt(px, py);
        if (into !== root.dropInto) {
            root.dropInto = into;
            var t = root.byKey[into];
            root.springKey = "";
            springTimer.stop();
            if (Prefs.desktopIconsSpring && t && (t.kind === "dir" || t.kind === "home" || t.kind === "drive")) {
                root.springKey = into;
                springTimer.restart();
            }
        }
    }

    Timer {
        id: springTimer

        interval: 1100
        onTriggered: {
            if (root.springKey !== "" && root.springKey === root.dropInto) {
                var it = root.byKey[root.springKey];
                if (it)
                    root.run(["python3", root.script, "open", it.uri]);

            }
            root.springKey = "";
        }
    }

    // a drop on the desktop layer. wayland reports it at the middle of the surface,
    // so the point is the last one the drag moved through
    function dropped(drop) {
        var px = root.dragX;
        var py = root.dragY;
        if (drop.formats.indexOf(root.appMime) >= 0) {
            try {
                root.addDockApp(JSON.parse(drop.getDataAsString(root.appMime)), px, py);
            } catch (e) {
            }
            root.leaveDrag();
            drop.accept(Qt.CopyAction);
            return ;
        }
        var into = root.targetAt(px, py);
        var ours = root.dragKey !== "";
        var how = root.actionOf(drop.proposedAction, ours);
        var uris = drop.hasUrls ? drop.urls.map((u) => {
            return String(u);
        }) : [];
        var target = into ? root.byKey[into] : null;
        if (ours && !target && how === "move")
            root.moveTo(root.dragKeys, root.dragKey, px, py);
        else if (target && target.kind === "trash")
            root.trashUris(uris);
        else if (target && target.kind === "app")
            root.openWith(into, uris);
        else
            root.put(how, uris, into, px, py);
        root.leaveDrag();
        drop.accept(how === "copy" ? Qt.CopyAction : (how === "link" ? Qt.LinkAction : Qt.MoveAction));
    }

    // what letting go here would do, for the chip beside the pointer
    readonly property string dropHint: {
        if (!root.dragOver)
            return "";

        if (root.dragApp)
            return "Add to Desktop";

        var t = root.byKey[root.dropInto];
        if (t) {
            if (t.kind === "trash")
                return "Move to Trash";

            if (t.kind === "app")
                return "Open with " + t.label;

            var verb = root.dropAction === "copy" ? "Copy" : (root.dropAction === "link" ? "Link" : "Move");
            return verb + " to " + t.label;
        }
        if (root.dragKey === "")
            return root.dropAction === "link" ? "Link here" : "Drop on the Desktop";

        return root.dropAction === "copy" ? "Copy here" : (root.dropAction === "link" ? "Link here" : "");
    }
    readonly property string dropHintIcon: {
        if (root.dragApp)
            return "add";

        var t = root.byKey[root.dropInto];
        if (t && t.kind === "trash")
            return "delete";

        if (t && t.kind === "app")
            return "open_in_new";

        return root.dropAction === "copy" ? "content_copy" : (root.dropAction === "link" ? "link" : "drive_file_move");
    }

    // ---- menus ----------------------------------------------------------------------

    // a strip button's name with its keys, for its tooltip
    function withHint(label, id) {
        var h = root.keyHint(id);
        return h ? label + "  \u00b7  " + h : label;
    }

    function row(id, label, glyph, extra) {
        return Object.assign({
            "id": id,
            "label": label,
            "glyph": glyph
        }, extra || ({}));
    }

    // the right-click menu for the icons under the pointer
    function openMenu(keys, px, py) {
        var rows = root.itemRows(keys);
        if (rows.length > 0)
            root.menuRequested(px, py, rows);

    }

    function itemRows(keys) {
        var items = keys.map((k) => {
            return root.byKey[k];
        }).filter((x) => {
            return x !== undefined;
        });
        if (items.length === 0)
            return [];

        var one = items.length === 1 ? items[0] : null;
        var files = root.filesOf(keys);
        var rows = [];
        // the everyday four, as icon buttons along the top
        if (files.length > 0)
            rows.push({
                "strip": [{
                    "id": "icon:cut",
                    "glyph": "content_cut",
                    "label": root.withHint("Cut", "cut")
                }, {
                    "id": "icon:copy",
                    "glyph": "content_copy",
                    "label": root.withHint("Copy", "copy")
                }, {
                    "id": "icon:rename",
                    "glyph": "edit",
                    "label": root.withHint("Rename", "rename"),
                    "disabled": !(one && files.length === 1)
                }, {
                    "id": "icon:trash",
                    "glyph": "delete",
                    "label": root.withHint("Move to Trash", "trash"),
                    "danger": true
                }]
            });

        if (one && one.kind === "app" && !one.exec)
            rows.push(root.row("icon:trust", "Allow Launching", "verified_user", {
                "divider": rows.length > 0
            }));
        else
            rows.push(root.row("icon:open", one ? (one.kind === "app" ? "Launch" : "Open") : "Open " + items.length + " Items", one && one.kind === "app" ? "play_arrow" : "open_in_new", {
                "shortcut": root.keyHint("open"),
                "divider": rows.length > 0
            }));
        if (one && (one.kind === "file" || one.kind === "dir" || one.kind === "app")) {
            rows.push(root.row("", "Open With", "apps", {
                "submenu": "openWith"
            }));
            root.fetchApps(one.uri);
        }
        if (one && root.canLook(one))
            rows.push(root.row("icon:look", "Quick Look", "visibility", {
                "shortcut": root.keyHint("look")
            }));

        if (one && one.kind !== "trash" && one.path !== "")
            rows.push(root.row("icon:info", "Get Info", "info", {
                "shortcut": root.keyHint("info")
            }));

        var group = [];
        var dirLike = one && (one.kind === "dir" || one.kind === "home" || one.kind === "drive");
        if (dirLike)
            group.push(root.row("icon:terminal", "Open in Terminal", "terminal", {
                "shortcut": root.keyHint("terminal")
            }));

        if (dirLike && root.canPaste)
            group.push(root.row("icon:pasteInto", root.clip.uris.length === 0 ? "Paste Picture Into Folder" : "Paste Into Folder", "content_paste"));

        if (files.length > 0) {
            if (one && root.isArchive(one))
                group.push(root.row("icon:extract", "Extract Here", "unarchive"));
            else
                group.push(root.row("icon:compress", files.length > 1 ? "Compress " + files.length + " Items" : "Compress", "folder_zip", {
                "shortcut": root.keyHint("compress")
            }));
            group.push(root.row("icon:duplicate", "Duplicate", "file_copy", {
                "shortcut": root.keyHint("duplicate")
            }));
            if (one)
                group.push(root.row("icon:link", "Make Link", "add_link"));

            group.push(root.row("", "Send To", "share", {
                "submenu": root.sendRows()
            }));
            group.push(root.row("", "Tags", "label", {
                "submenu": root.tagRows(files)
            }));
        }
        if (one && one.kind === "trash")
            group.push(root.row("icon:empty", "Empty Trash", "delete_sweep", {
                "danger": true,
                "disabled": root.trashCount === 0
            }));

        if (one && one.kind === "drive" && (one.canEject || one.canUnmount))
            group.push(root.row(one.canEject ? "icon:eject" : "icon:unmount", one.canEject ? "Eject" : "Unmount", "eject"));

        for (var i = 0; i < group.length; i++) {
            if (i === 0)
                group[i].divider = true;

            rows.push(group[i]);
        }
        if (files.length > 0)
            rows.push(root.row("icon:path", files.length > 1 ? "Copy Paths" : "Copy Path", "link", {
                "shortcut": root.keyHint("copyPath"),
                "divider": true
            }));

        return rows;
    }

    // the home folders a copy can go to, phones kde connect can reach, and
    // paired bluetooth devices that take files
    function sendRows() {
        var rows = [];
        var places = root.places;
        for (var i = 0; i < places.length; i++)
            rows.push(root.row("send:" + i, places[i].label, places[i].glyph));
        var phones = KdeConnect.active ? KdeConnect.reachable : [];
        for (var j = 0; j < phones.length; j++)
            rows.push(root.row("phone:" + phones[j].id, phones[j].name, "smartphone", {
                "divider": j === 0 && rows.length > 0
            }));
        var bt = root.btTargets();
        for (var k = 0; k < bt.length; k++)
            rows.push(root.row("bt:" + bt[k].address, bt[k].name || bt[k].address, "bluetooth", {
                "divider": k === 0 && rows.length > 0
            }));
        if (rows.length === 0)
            rows.push(root.row("", "Nowhere to send", "", {
                "disabled": true
            }));

        return rows;
    }

    function tagRows(files) {
        var rows = [];
        for (var i = 0; i < root.tagNames.length; i++) {
            var t = root.tagNames[i];
            rows.push(root.row("tag:" + t, root.tagLabel(t), "", {
                "swatch": root.tagColor(t),
                "check": files.length > 0 && files.every((e) => {
                    return e.tags.indexOf(t) >= 0;
                })
            }));
        }
        rows.push(root.row("tag:clear", "Clear Tags", "label_off", {
            "divider": true,
            "disabled": !files.some((e) => {
                return e.tags.length > 0;
            })
        }));
        return rows;
    }

    // the desktop's own entries, at the top of its menu
    function desktopRows() {
        var rows = [];
        rows.push(root.row("", "New Item", "note_add", {
            "submenu": root.newRows()
        }));
        rows.push(root.row("paste", root.clip.uris.length === 0 && root.clip.image ? "Paste Picture" : "Paste", "content_paste", {
            "shortcut": root.keyHint("paste"),
            "disabled": !root.canPaste,
            "divider": true
        }));
        if (root.lastUndo)
            rows.push(root.row("undo", root.lastUndo.label, "undo", {
                "shortcut": root.keyHint("undo")
            }));

        rows.push(root.row("", "View", "grid_view", {
            "submenu": root.viewRows(),
            "divider": true
        }));
        rows.push(root.row("", "Arrange By", "sort", {
            "submenu": root.arrangeRows()
        }));
        rows.push(root.row("selectAll", "Select All", "select_all", {
            "shortcut": root.keyHint("selectAll")
        }));
        rows.push(root.row("terminal", "Open in Terminal", "terminal", {
            "shortcut": root.keyHint("terminal"),
            "divider": true
        }));
        rows.push(root.row("openDesktop", "Open Desktop in Files", "folder_open"));
        return rows;
    }

    function newRows() {
        var rows = [root.row("new:folder", "Folder", "create_new_folder", {
            "shortcut": root.keyHint("newFolder")
        }), root.row("new:text", "Text Document", "description", {
            "shortcut": root.keyHint("newText")
        }), root.row("new:markdown", "Markdown Document", "description"), root.row("new:empty", "Empty File", "draft")];
        for (var i = 0; i < root.templates.length; i++)
            rows.push(root.row("new:tpl:" + i, root.templates[i].label, root.templates[i].icon ? "" : "description", {
                "image": root.templates[i].icon ? "file://" + root.templates[i].icon : "",
                "divider": i === 0
            }));
        rows.push(root.row("new:app", "App Shortcut…", "apps", {
            "divider": true
        }));
        return rows;
    }

    // what shows on the desktop at all; the menu keeps these even while the icons are away
    function showRows() {
        var rows = [];
        if (Prefs.desktopIcons)
            rows.push(root.row("view:icons", "Show Desktop Icons", "folder", {
                "check": Prefs.desktopIconsShown
            }));

        if (Widgets.count > 0)
            rows.push(root.row("view:widgets", "Show Widgets", "dashboard", {
                "check": Prefs.widgetsEnabled
            }));

        return rows;
    }

    // how long after the wave starts an icon at this spot moves
    function waveDelay(spot, step) {
        return spot ? Math.min(30, spot.c + spot.r) * step : 0;
    }

    function viewRows() {
        var show = root.showRows();
        return show.concat([root.row("view:small", "Small Icons", "", {
            "check": Prefs.desktopIconSize === "small",
            "divider": show.length > 0
        }), root.row("view:medium", "Medium Icons", "", {
            "check": Prefs.desktopIconSize === "medium"
        }), root.row("view:large", "Large Icons", "", {
            "check": Prefs.desktopIconSize === "large"
        }), root.row("view:compact", "Compact Spacing", "", {
            "check": Prefs.desktopIconSpacing === "compact",
            "divider": true
        }), root.row("view:normal", "Normal Spacing", "", {
            "check": Prefs.desktopIconSpacing === "normal"
        }), root.row("view:roomy", "Roomy Spacing", "", {
            "check": Prefs.desktopIconSpacing === "roomy"
        }), root.row("view:auto", "Auto Arrange", "", {
            "check": Prefs.desktopIconsAutoArrange,
            "divider": true
        }), root.row("view:hidden", "Show Hidden Files", "", {
            "check": Prefs.desktopIconsHidden,
            "shortcut": root.keyHint("hidden")
        }), root.row("view:ext", "Show File Extensions", "", {
            "check": !Prefs.desktopIconsHideExt
        }), root.row("view:thumbs", "Show Previews", "", {
            "check": Prefs.desktopIconsThumbs
        })]);
    }

    function arrangeRows() {
        var hows = [["name", "Name"], ["type", "Type"], ["size", "Size"], ["date", "Modified"]];
        var rows = [];
        for (var i = 0; i < hows.length; i++)
            rows.push(root.row("arrange:" + hows[i][0], hows[i][1], "", {
                "check": Prefs.desktopIconsSort === hows[i][0]
            }));
        rows.push(root.row("arrange:asc", "Ascending", "", {
            "check": !Prefs.desktopIconsSortDesc,
            "divider": true
        }));
        rows.push(root.row("arrange:desc", "Descending", "", {
            "check": Prefs.desktopIconsSortDesc
        }));
        return rows;
    }

    // a submenu filled in later, by name
    function submenu(name) {
        if (name === "openWith")
            return root.openWithRows();

        return [];
    }

    // the apps that open the file a menu is for, fetched when the menu opens
    property var openWithApps: []
    property string openWithUri: ""
    property bool openWithBusy: false

    function fetchApps(uri) {
        if (root.openWithUri === uri && root.openWithApps.length > 0)
            return ;

        root.openWithUri = uri;
        root.openWithApps = [];
        root.openWithBusy = true;
        appsProc.running = false;
        appsProc.command = ["python3", root.script, "apps-for", uri].concat(root.themeArgs(Theme.dp(24)));
        appsProc.running = true;
    }

    function openWithRows() {
        var apps = root.openWithApps;
        var rows = [];
        for (var i = 0; i < apps.length; i++)
            rows.push(root.row("app:" + i, apps[i].name, apps[i].icon ? "" : "apps", {
                "image": apps[i].icon ? "file://" + apps[i].icon : "",
                "shortcut": apps[i]["default"] ? "Default" : ""
            }));
        if (apps.length === 0)
            rows.push(root.row("", root.openWithBusy ? "Looking…" : "No apps for this file", "", {
                "disabled": true
            }));

        return rows;
    }

    // which actions are the desktop icons' to run
    function owns(id) {
        return /^(icon|app|send|phone|tag|new|view|arrange):/.test(id) || ["paste", "undo", "selectAll", "terminal", "openDesktop"].indexOf(id) >= 0;
    }

    function runAction(id) {
        var keys = root.selectedKeys;
        var one = keys.length === 1 ? root.byKey[keys[0]] : null;
        if (id === "icon:open") {
            root.openSelection();
        } else if (id.indexOf("app:") === 0) {
            var app = root.openWithApps[parseInt(id.substring(4))];
            var f = root.filesOf(keys);
            if (app && f.length > 0)
                root.run(["gio", "launch", app.file].concat(root.pathsOf(f)));

        } else if (id === "icon:look") {
            if (one)
                root.quickLook(one.key);

        } else if (id === "icon:info") {
            if (one)
                root.getInfo(one.key);

        } else if (id === "icon:trust") {
            if (one)
                root.run(["python3", root.script, "trust", one.path]);

        } else if (id === "icon:empty") {
            root.emptyTrash();
        } else if (id === "icon:eject") {
            if (one)
                root.run(["gio", "mount", "-e", one.uri]);

        } else if (id === "icon:unmount") {
            if (one)
                root.run(["gio", "mount", "-u", one.uri]);

        } else if (id === "icon:rename") {
            if (root.filesOf(keys).length === 1)
                root.renaming = keys[0];

        } else if (id === "icon:cut") {
            root.cut(keys);
        } else if (id === "icon:copy") {
            root.copy(keys);
        } else if (id === "icon:path") {
            root.copyPath(keys);
        } else if (id === "icon:trash") {
            root.trash(keys);
        } else if (id === "icon:terminal") {
            if (one)
                root.openTerminal(one.path);

        } else if (id === "icon:pasteInto") {
            if (one) {
                var c = root.centreOf(one.key);
                root.menuX = c ? c.x : root.menuX;
                root.menuY = c ? c.y : root.menuY;
                root.paste(one.key);
            }
        } else if (id === "icon:compress" || id === "icon:extract" || id === "icon:duplicate" || id === "icon:link") {
            root.make(id.substring(5), keys);
        } else if (id.indexOf("send:") === 0) {
            var pl = root.places[parseInt(id.substring(5))];
            if (pl)
                root.sendTo(pl.path, pl.label, keys);

        } else if (id.indexOf("phone:") === 0) {
            var dev = KdeConnect.reachable.filter((d) => {
                return d.id === id.substring(6);
            })[0];
            if (dev)
                root.sendToPhone(dev.id, dev.name, keys);

        } else if (id.indexOf("bt:") === 0) {
            root.sendOverBluetooth(id.substring(3), keys);
        } else if (id === "tag:clear") {
            root.clearTags(keys);
        } else if (id.indexOf("tag:") === 0) {
            root.toggleTag(id.substring(4), keys);
        } else if (id.indexOf("new:tpl:") === 0) {
            var tpl = root.templates[parseInt(id.substring(8))];
            if (tpl)
                root.newItem("template", tpl.path);

        } else if (id === "new:app") {
            Prefs.appPickerRequested("::desktop");
        } else if (id.indexOf("new:") === 0) {
            root.newItem(id.substring(4), "");
        } else if (id === "view:small" || id === "view:medium" || id === "view:large") {
            Prefs.desktopIconSize = id.substring(5);
        } else if (id === "view:compact" || id === "view:normal" || id === "view:roomy") {
            Prefs.desktopIconSpacing = id.substring(5);
        } else if (id === "view:auto") {
            Prefs.desktopIconsAutoArrange = !Prefs.desktopIconsAutoArrange;
        } else if (id === "view:hidden") {
            Prefs.desktopIconsHidden = !Prefs.desktopIconsHidden;
        } else if (id === "view:ext") {
            Prefs.desktopIconsHideExt = !Prefs.desktopIconsHideExt;
        } else if (id === "view:thumbs") {
            Prefs.desktopIconsThumbs = !Prefs.desktopIconsThumbs;
        } else if (id === "view:hide") {
            Prefs.desktopIconsShown = false;
        } else if (id === "view:icons") {
            Prefs.desktopIconsShown = !Prefs.desktopIconsShown;
        } else if (id === "view:widgets") {
            Prefs.widgetsEnabled = !Prefs.widgetsEnabled;
        } else if (id === "arrange:asc" || id === "arrange:desc") {
            Prefs.desktopIconsSortDesc = id === "arrange:desc";
            Qt.callLater(root.arrange);
        } else if (id.indexOf("arrange:") === 0) {
            root.arrangeBy(id.substring(8));
        } else if (id === "paste") {
            root.paste("");
        } else if (id === "undo") {
            root.undo();
        } else if (id === "selectAll") {
            root.selectAll();
        } else if (id === "terminal") {
            root.openTerminal(root.dir || root.home + "/Desktop");
        } else if (id === "openDesktop") {
            root.run(["python3", root.script, "open", "file://" + (root.dir || root.home + "/Desktop")]);
        }
    }

    // ---- plumbing ----------------------------------------------------------------------

    // the folders send to copies into, from the helper: [{label, path, glyph}]
    property var places: []
    // ~/Templates, for new item: [{label, path, icon}]
    property var templates: []

    function saveHomes() {
        store.homes = root.homes;
    }

    onItemsChanged: root.scheduleLayout()
    onColsChanged: root.scheduleLayout()
    onRowsChanged: root.scheduleLayout()
    onFromRightChanged: root.scheduleLayout()
    onLiveChanged: {
        if (root.live) {
            leaveTimer.stop();
            root.leaving = false;
            root.waking = true;
            wakeTimer.restart();
        } else if (Prefs.loaded) {
            // up for the last icon's turn in the wave, and its fade
            var far = 0;
            for (var k in root.placed)
                far = Math.max(far, root.waveDelay(root.placed[k], root.stowStep));
            leaveTimer.interval = far + Theme.durShort + 60;
            root.leaving = true;
            leaveTimer.restart();
        }
        root.restartWatcher();
        if (root.live && root.lumaFor === "")
            root.measureWallpaper(wallFile.text().trim());

        if (root.live) {
            root.collectWidgets();
            root.scheduleLayout();
        } else {
            root.clearSelection();
            root.renaming = "";
            root.lookKey = "";
            root.infoKey = "";
            root.dialog = null;
            root.snack = null;
            root.armed = false;
        }
    }

    Connections {
        function onDesktopIconsAutoArrangeChanged() {
            root.scheduleLayout();
        }

        function onDesktopIconsSortDescChanged() {
            root.scheduleLayout();
        }

        target: Prefs
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
            restTimer.restart();
        }

        function onLiveUidChanged() {
            widgetTimer.restart();
        }

        target: Widgets
        enabled: root.live
    }

    Connections {
        // put away, the cards fade before the icons take their room
        function onWidgetsEnabledChanged() {
            if (Prefs.widgetsEnabled) {
                widgetsGone.stop();
                widgetTimer.restart();
            } else {
                widgetsGone.restart();
            }
        }

        target: Prefs
        enabled: root.live
    }

    Timer {
        id: widgetsGone

        interval: Widgets.count * Math.round(30 * Theme.motionScale) + Theme.durMedium
        onTriggered: widgetTimer.restart()
    }

    Timer {
        id: widgetTimer

        // a frame: a drag reports far more often than icons need to move
        interval: 16
        onTriggered: {
            root.collectWidgets();
            root.relayout();
        }
    }

    // a widget being dragged moves the icons once it rests over them, not on its way across
    Timer {
        id: restTimer

        interval: 150
        onTriggered: widgetTimer.restart()
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
                root.specials = d.specials || ({});
                root.drives = d.drives || [];
                root.templates = d.templates || [];
                root.places = d.places || [];
                root.noteArrivals(d.items);
                root.files = d.items;
                root.listed = true;
                root.pruneHomes();
                // a cut file that has gone (pasted somewhere) is no longer cut
                var cut = Object.keys(root.cutKeys);
                if (cut.length > 0 && cut.some((k) => {
                    return root.byKey[k] === undefined;
                })) {
                    var m = {};
                    cut.forEach((k) => {
                        if (root.byKey[k] !== undefined)
                            m[k] = true;

                    });
                    root.cutKeys = m;
                }
                if (root.pendingRename !== "" && root.byKey[root.pendingRename] !== undefined) {
                    root.selectOnly(root.pendingRename);
                    root.renaming = root.pendingRename;
                    root.pendingRename = "";
                }
            }
        }

    }

    // icons for a size in logical pixels, from the art drawn for this screen's density
    function themeArgs(px) {
        return ["--theme", root.themeName, "--size", String(px), "--scale", String(Math.max(1, Math.round(root.dpr)))];
    }

    // what the watcher needs to know, all read when it starts
    readonly property var watchArgs: root.themeArgs(root.iconPx).concat(Prefs.desktopIconsHidden ? ["--hidden"] : []).concat(Prefs.desktopIconsThumbs ? ["--thumbs"] : []).concat(Prefs.desktopIconsDrives ? ["--drives"] : [])

    onWatchArgsChanged: {
        if (root.live)
            restartTimer.restart();

    }

    // a theme switch writes several prefs; one restart for all of them
    Timer {
        id: restartTimer

        interval: 120
        onTriggered: root.restartWatcher()
    }

    function restartWatcher() {
        watcher.running = false;
        if (!root.live)
            return ;

        watcher.command = ["python3", root.script, "watch"].concat(root.watchArgs);
        watcher.running = true;
    }

    Component.onCompleted: {
        root.homes = store.homes || ({});
        root.restartWatcher();
    }

    Timer {
        id: leaveTimer

        onTriggered: root.leaving = false
    }

    Timer {
        id: wakeTimer

        interval: 1500
        onTriggered: root.waking = false
    }

    Process {
        id: appsProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.openWithApps = JSON.parse(text).apps || [];
                } catch (e) {
                    root.openWithApps = [];
                }
                root.openWithBusy = false;
            }
        }

    }

    Process {
        id: infoProc

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    root.info = JSON.parse(line);
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: chmodProc

        onExited: {
            if (root.infoKey !== "")
                root.getInfo(root.infoKey);

            refreshTimer.restart();
        }
    }

    Process {
        id: clipProc

        command: ["python3", root.script, "clip"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var c = JSON.parse(text);
                    // our own cut stays a cut even after a file manager rewrote the clipboard as a plain list
                    root.clip = c;
                } catch (e) {
                }
                root.doPaste();
            }
        }

    }

    // while something is cut, a change of clipboard by anyone else uncuts it
    Timer {
        id: clipWatchStart

        interval: 400
        onTriggered: {
            clipWatch.seen = 0;
            clipWatch.running = false;
            clipWatch.running = Object.keys(root.cutKeys).length > 0;
        }
    }

    Process {
        id: clipWatch

        property int seen: 0

        command: ["wl-paste", "--watch", "echo", "changed"]
        running: false

        stdout: SplitParser {
            onRead: (line) => {
                // the first line is the clipboard as it stands, our own cut
                clipWatch.seen++;
                if (clipWatch.seen > 1) {
                    root.cutKeys = ({});
                    clipWatch.running = false;
                }
            }
        }

    }

    // new items and duplicates, links, archives: each line is "<src>\t<new name>" or just a name
    Component {
        id: makeProc

        Process {
            id: mp

            property point placeAt
            property string what: ""
            property bool intoDesktop: true
            property string destDir: ""
            property var made: []

            onExited: (code) => {
                if (mp.made.length > 0) {
                    var labels = {
                        "folder": "Undo New Folder",
                        "text": "Undo New Document",
                        "markdown": "Undo New Document",
                        "empty": "Undo New File",
                        "template": "Undo New Document",
                        "duplicate": "Undo Duplicate",
                        "link": "Undo Make Link",
                        "compress": "Undo Compress",
                        "extract": "Undo Extract",
                        "app": "Undo Add to Desktop",
                        "image": "Undo Paste"
                    };
                    root.pushUndo({
                        "label": labels[mp.what] || "Undo",
                        "kind": "created",
                        "paths": mp.made
                    });
                    if (mp.what === "compress")
                        root.notify("Compressed to “" + root.baseOf(mp.made[0]) + "”", true);
                    else if (mp.what === "extract")
                        root.notify("Extracted “" + root.baseOf(mp.made[0]) + "”", true);
                } else if (code !== 0 && mp.what !== "") {
                    root.notify(mp.what === "image" ? "There's no picture on the clipboard" : "That didn't work", false);
                }
                mp.destroy();
            }

            stdout: SplitParser {
                onRead: (line) => {
                    var tab = line.indexOf("\t");
                    var name = tab < 0 ? line : line.substring(tab + 1);
                    if (name === "")
                        return ;

                    // duplicates and the like land beside their source, which is on the desktop
                    mp.made = mp.made.concat([(mp.destDir || root.dir) + "/" + name]);
                    if (!mp.intoDesktop)
                        return ;

                    root.expect([name], mp.placeAt.x, mp.placeAt.y);
                    if (["folder", "text", "markdown", "empty", "template"].indexOf(mp.what) >= 0)
                        root.pendingRename = name;

                }
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
            property string mode: "auto"
            property string destDir: ""
            property string destLabel: ""
            property string destKey: ""
            // [new path, where it came from]
            property var moved: []

            onExited: {
                if (proc.moved.length > 0) {
                    var gone = proc.mode === "move" || proc.mode === "auto";
                    if (gone && proc.moved.some((m) => {
                        return m[1] !== "";
                    })) {
                        root.pushUndo({
                            "label": "Undo Move",
                            "kind": "relocate",
                            "pairs": proc.moved.filter((m) => {
                                return m[1] !== "";
                            })
                        });
                    } else {
                        root.pushUndo({
                            "label": proc.mode === "link" ? "Undo Make Link" : "Undo Copy",
                            "kind": "created",
                            "paths": proc.moved.map((m) => {
                                return m[0];
                            })
                        });
                    }
                    if (!proc.intoDesktop) {
                        var n = proc.moved.length;
                        var verb = proc.mode === "copy" ? "Copied" : (proc.mode === "link" ? "Linked" : "Moved");
                        root.notify(verb + " " + (n === 1 ? "“" + root.baseOf(proc.moved[0][0]) + "”" : n + " items") + " to " + proc.destLabel, true);
                        if (proc.destKey !== "") {
                            root.received = proc.destKey;
                            root.receiveTick++;
                        }
                    }
                }
                proc.destroy();
            }

            stdout: SplitParser {
                // a name that had to change ("photo (2).png") takes the cell the old one was promised
                onRead: (line) => {
                    var tab = line.indexOf("\t");
                    if (tab < 0)
                        return ;

                    var uri = line.substring(0, tab);
                    var name = line.substring(tab + 1);
                    var src = uri.indexOf("file://") === 0 ? decodeURIComponent(uri.substring(7)) : "";
                    var dest = (proc.destDir || root.dir) + "/" + name;
                    // dropped where it already was: nothing moved
                    if (src !== dest)
                        proc.moved = proc.moved.concat([[dest, proc.mode === "copy" || proc.mode === "link" ? "" : src]]);

                    if (!proc.intoDesktop)
                        return ;

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
                        // the asked name was an icon already here, which keeps its cell
                        root.expect([name], proc.placeAt.x, proc.placeAt.y);
                    }
                }
            }

        }

    }

    Component {
        id: peekProc

        Process {
            id: pp

            property string dir: ""

            // gone once the output is in: exited can come before the stream ends
            stdout: StdioCollector {
                onStreamFinished: {
                    var m = Object.assign({}, root.peeks);
                    try {
                        m[pp.dir] = JSON.parse(text);
                    } catch (e) {
                        m[pp.dir] = {
                            "count": 0,
                            "items": []
                        };
                    }
                    root.peeks = m;
                    pp.destroy();
                }
            }

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

    IpcHandler {
        target: "desktop"

        // qs ipc call desktop icons
        function icons(): void {
            if (Prefs.desktopIcons)
                Prefs.desktopIconsShown = !Prefs.desktopIconsShown;

        }

        function arrange(): void {
            root.arrange();
        }

        function selectAll(): void {
            root.selectAll();
        }

        function undo(): void {
            root.undo();
        }

        function refresh(): void {
            root.restartWatcher();
        }
    }

}
