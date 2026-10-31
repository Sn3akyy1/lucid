import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.lucidlumen
import qs.lucidui

// one lens window: a picture on its stage, the rest of its folder in the strip
// below, sorted as lumen shows the folder, and the editor beside it. edits wait
// per picture until they are saved, so moving on never loses them
FloatingWindow {
    id: win

    required property var app
    required property string winId
    // the files it was opened with, one a line
    required property string startFiles
    property string folder: ""
    // several files opened together are a set of their own, not their folder
    property bool picked: false
    // pictures pasted from the clipboard: saving makes a copy in pictures
    property bool pasted: false
    property var raw: []
    property var items: []
    property int index: -1
    readonly property var current: win.index >= 0 && win.index < win.items.length ? win.items[win.index] : null
    property string landOn: ""
    property var info: null
    property var _byPath: ({})
    // where each path sits in the strip, which runs in the order of items
    property var _rows: ({})
    // a picture written again keeps its thumbnail's path, so its tiles load the
    // new one under a number not used before, kept here by path
    property var _revs: ({})
    property int _revNext: 1
    // "view" | "edit"
    property string mode: "view"
    // "crop" | "adjust" | "filters" | "markup"
    property string tab: "adjust"
    property bool showInfo: false
    property bool overview: false
    property bool immersive: false
    property bool slideshow: false
    property bool comparing: false
    property bool busy: false
    property bool slidePaused: false
    // the eyedropper is out
    property bool picking: false
    // videos: where each was left, by path, so going back carries on; how fast they play
    property var positions: ({})
    property real rate: 1
    // the trim panel is out (Trimmer.qml)
    property bool trimming: false
    // the crop's shape stood on end, and the straighten slider in hand
    property bool cropPortrait: false
    property bool straightening: false
    // edits by path, kept until saved or thrown away; and each one's undo steps
    property var pending: ({})
    property var steps: ({})
    property var _live: null
    readonly property var edits: win.current && win.pending[win.current.path] ? win.pending[win.current.path] : win.blank
    readonly property var blank: ({
        "turns": 0,
        "flipH": false,
        "flipV": false,
        "angle": 0,
        "crop": null,
        "adjust": {},
        "filter": "",
        "marks": []
    })
    readonly property bool dirty: win.current !== null && win.pending[win.current.path] !== undefined
    readonly property int dirtyCount: Object.keys(win.pending).length
    readonly property var stepsHere: win.current ? (win.steps[win.current.path] || {
        "past": [],
        "future": []
    }) : {
        "past": [],
        "future": []
    }
    readonly property bool canEdit: win.current !== null && !win.current.animated && !win.current.broken && !win.current.video
    readonly property bool isVideo: win.current !== null && win.current.video === true
    // a video turns by the note in it that says which way is up, where its kind has one
    readonly property bool canTurn: win.canEdit || (win.isVideo && !win.current.broken && win.app.turnableKind(win.current.path))
    // the original lens kept of the picture on show, from its details:
    // {file, thumb, at, size, w, h, changed}
    readonly property var kept: win.info && win.current && win.info.path === win.current.path && win.info.original ? win.info.original : null
    // the info panel's original, pressed and held
    property bool holdingOriginal: false
    // the kept original stands in on the stage: held there, or compare held with no edits pending.
    // a picture's only: a video's original is a video
    readonly property bool peeking: win.kept !== null && !win.isVideo && (win.holdingOriginal || (win.comparing && !win.dirty))
    // the mark being drawn, in the picture's own pixels
    property var draft: null
    readonly property bool narrow: root.width < Theme.dp(760)
    readonly property real panelTarget: win.immersive ? 0 : (win.mode === "edit" ? Theme.dp(348) : (win.showInfo && root.width >= Theme.dp(820) ? Theme.dp(320) : 0))
    property real panelW: win.panelTarget
    readonly property bool stripOn: !win.immersive && win.mode === "view" && !win.trimming && win.app.prefs.filmstrip && win.items.length > 1
    property real stripH: win.stripOn ? Theme.dp(84) : 0
    // the trim panel's room under the stage
    property real trimH: win.trimming && win.isVideo ? trimmer.panelH + Theme.dp(12) : 0
    readonly property real barH: win.immersive ? 0 : Theme.dp(64)
    readonly property real edge: win.immersive ? 0 : Theme.dp(12)
    readonly property alias stageView: stage

    Behavior on panelW {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on stripH {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on trimH {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    // ---- what is shown, and in what order

    function decorate(e) {
        var x = Object.assign({}, e);
        var ext = win.app.extOf(e.path);
        x.animated = win.app.animatedKind(e.path);
        x.vector = win.app.vectorKind(e.path);
        x.video = win.app.videoKind(e.path);
        x.canAlpha = ["png", "webp", "gif", "svg", "svgz", "tif", "tiff", "ico", "icns", "avif", "tga", "heic", "heif", "jxl", "qoi", "exr"].indexOf(ext) >= 0;
        var had = win._byPath[e.path];
        x.decoded = had ? had.decoded || "" : "";
        x.display = win.app.qtShows(e.path) ? win.app.uriOf(e.path) + (x.mtime ? "?v=" + x.mtime : "") : (x.decoded ? "file://" + x.decoded : "");
        if (had && had.thumb && !x.thumb)
            x.thumb = had.thumb;

        if (had && had.broken)
            x.broken = true;

        return x;
    }

    function rebuild() {
        var keep = win.landOn !== "" ? win.landOn : win.current ? win.current.path : "";
        var list = win.raw.map(win.decorate);
        // videos sit out while they are switched off, unless one was opened itself
        if (!win.app.prefs.videos)
            list = list.filter(function(it) {
            return !it.video || it.path === keep;
        });

        if (!win.picked || win.app.parentOf(list.length ? list[0].path : "") === win.folder)
            list = win.app.sorted(list, win.folder);

        var by = {};
        for (var i = 0; i < list.length; i++) by[list[i].path] = list[i]
        win._byPath = by;
        var at = -1;
        for (var k = 0; k < list.length; k++) {
            if (list[k].path === keep) {
                at = k;
                break;
            }
        }
        // the one shown went away: the next one takes its place
        if (at < 0 && list.length > 0)
            at = Math.min(Math.max(0, win.index), list.length - 1);

        win.items = list;
        win.syncStrip();
        if (at !== win.index)
            win.index = at;
        else
            win.ensureShown();
        // kept until the listing that holds it arrives
        if (at >= 0 && list[at].path === win.landOn)
            win.landOn = "";

    }

    function syncStrip() {
        var same = strip.count === win.items.length;
        for (var i = 0; same && i < win.items.length; i++) {
            if (win._rows[win.items[i].path] !== i)
                same = false;

        }
        if (!same) {
            var rows = {};
            strip.clear();
            for (var j = 0; j < win.items.length; j++) {
                rows[win.items[j].path] = j;
                strip.append({
                    "path": win.items[j].path,
                    "name": win.items[j].name,
                    "thumb": win.items[j].thumb || "",
                    "failed": false,
                    "rev": win._revs[win.items[j].path] || 0,
                    "video": win.items[j].video === true
                });
            }
            win._rows = rows;
            win.askThumbs();
        }
    }

    function setItem(path, patch) {
        var e = win._byPath[path];
        if (!e)
            return ;

        var list = win.items.slice();
        for (var i = 0; i < list.length; i++) {
            if (list[i].path === path) {
                list[i] = Object.assign({}, list[i], patch);
                win._byPath[path] = list[i];
                break;
            }
        }
        win.items = list;
    }

    // thumbnails nearest the one shown first, the folder's own cache where it is fresh
    function askThumbs() {
        var n = win.items.length;
        if (n === 0)
            return ;

        // the index can still point past a list that just got shorter
        var at = Math.min(n - 1, Math.max(0, win.index)), out = [];
        for (var d = 0; d < n && out.length < 4000; d++) {
            var a = at + d, b = at - d;
            if (a < n && !win.items[a].thumb)
                out.push({
                "path": win.items[a].path,
                "mtime": win.items[a].mtime
            });

            if (d > 0 && b >= 0 && !win.items[b].thumb)
                out.push({
                "path": win.items[b].path,
                "mtime": win.items[b].mtime
            });

        }
        if (out.length > 0)
            win.app.call("thumbs", {
            "items": out
        });

    }

    function load(files) {
        var list = (files || "").split("\n").filter(function(s) {
            return s !== "";
        });
        // nothing asked for: the pictures folder
        if (list.length === 0) {
            win.folder = win.app.caps.pictures || (win.app.home + "/Pictures");
            win.listFolder();
            return ;
        }
        win.picked = list.length > 1;
        win.landOn = list[0];
        win.folder = win.app.parentOf(list[0]);
        if (win.picked) {
            win.app.call("files", {
                "paths": list
            }, function(r) {
                win.raw = r.items || [];
                win.rebuild();
            });
            return ;
        }
        // one path: a folder opens at its first picture, a file at itself
        win.app.call("files", {
            "paths": [list[0]]
        }, function(r) {
            var isFile = (r.items || []).length > 0;
            if (!isFile) {
                win.folder = list[0];
                win.landOn = "";
            }
            win.listFolder();
        });
    }

    function listFolder() {
        win.app.call("list", {
            "path": win.folder,
            "hidden": win.app.lumen.hidden
        }, function(r) {
            if (!r.ok) {
                win.say(r.error || "Can't open that folder");
                return ;
            }
            win.raw = r.items || [];
            win.rebuild();
        });
    }

    // read straight from the list: in onIndexChanged, win.current is not caught up yet
    function ensureShown() {
        if (!win.items[win.index])
            return ;

        // what qt can't read itself is turned into a png first
        var near = [win.index, win.index + 1, win.index - 1];
        for (var i = 0; i < near.length; i++) {
            var e = win.items[near[i]];
            if (e && !e.display && !e.broken && !e.decoding)
                win.decode(e.path);

        }
    }

    function decode(path) {
        win.setItem(path, {
            "decoding": true
        });
        win.app.call("decode", {
            "path": path
        }, function(r) {
            if (r.ok)
                win.setItem(path, {
                "decoding": false,
                "decoded": r.src,
                "display": "file://" + r.src
            });
            else
                win.setItem(path, {
                "decoding": false,
                "broken": true,
                "why": r.error || ""
            });
        });
    }

    onIndexChanged: {
        win.ensureShown();
        win.info = null;
        infoLater.restart();
        win.draft = null;
        if (win.overview === false && filmstrip)
            filmstrip.follow();

    }

    onCurrentChanged: {
        if (win.current && win.mode === "edit" && !win.canEdit)
            win.mode = "view";

        if (win.trimming && !win.isVideo)
            win.closeTrim();

    }

    Timer {
        id: infoLater

        interval: 140
        onTriggered: {
            var c = win.current;
            if (!c)
                return ;

            win.app.call("info", {
                "path": c.path
            }, function(r) {
                if (win.current && win.current.path === r.path)
                    win.info = r;

            });
        }
    }

    // ---- moving about

    function go(delta) {
        if ((win.mode === "edit" && win.tab === "crop") || win.trimming)
            return ;

        stage.go(delta);
    }

    function jump(i) {
        if (i < 0 || i >= win.items.length || i === win.index || win.trimming)
            return ;

        win.index = i;
    }

    // ---- edits, per picture

    function editsOf(path) {
        return win.pending[path] || null;
    }

    function isBlank(e) {
        if (!e)
            return true;

        if (e.turns % 4 || e.flipH || e.flipV || e.angle || e.crop || (e.marks && e.marks.length) || e.filter)
            return false;

        for (var k in e.adjust || {}) {
            if (e.adjust[k])
                return false;

        }
        return true;
    }

    function store(e) {
        var c = win.current;
        if (!c)
            return ;

        var p = Object.assign({}, win.pending);
        if (win.isBlank(e)) {
            delete p[c.path];
        } else {
            var full = stage.current;
            if (full && full.ready && !e.natW) {
                e = Object.assign({}, e);
                e.natW = full.natW;
                e.natH = full.natH;
            }
            p[c.path] = e;
        }
        win.pending = p;
    }

    function record(before) {
        var c = win.current;
        if (!c)
            return ;

        var s = Object.assign({}, win.steps);
        var mine = s[c.path] || {
            "past": [],
            "future": []
        };
        s[c.path] = {
            "past": mine.past.concat([before]).slice(-100),
            "future": []
        };
        win.steps = s;
    }

    function change(patch) {
        var before = win.edits;
        win.record(before);
        win.store(Object.assign({}, before, patch));
    }

    // a slider or a handle being dragged: every frame shows, one undo step in all
    function live(patch) {
        if (win._live === null)
            win._live = win.edits;

        win.store(Object.assign({}, win.edits, patch));
    }

    function settled() {
        if (win._live === null)
            return ;

        var before = win._live;
        win._live = null;
        if (JSON.stringify(before) !== JSON.stringify(win.edits))
            win.record(before);

    }

    function setAdjust(key, value, dragging) {
        var a = Object.assign({}, win.edits.adjust);
        a[key] = Math.round(value);
        if (dragging)
            win.live({
            "adjust": a,
            "filter": ""
        });
        else
            win.change({
            "adjust": a,
            "filter": ""
        });
    }

    function undo() {
        var c = win.current, mine = win.stepsHere;
        if (!c || mine.past.length === 0)
            return ;

        var s = Object.assign({}, win.steps);
        s[c.path] = {
            "past": mine.past.slice(0, -1),
            "future": [win.edits].concat(mine.future)
        };
        win.steps = s;
        win.store(mine.past[mine.past.length - 1]);
    }

    function redo() {
        var c = win.current, mine = win.stepsHere;
        if (!c || mine.future.length === 0)
            return ;

        var s = Object.assign({}, win.steps);
        s[c.path] = {
            "past": mine.past.concat([win.edits]),
            "future": mine.future.slice(1)
        };
        win.steps = s;
        win.store(mine.future[0]);
    }

    function revert() {
        if (!win.dirty)
            return ;

        win.change(win.blank);
    }

    function forget(path) {
        var p = Object.assign({}, win.pending), s = Object.assign({}, win.steps);
        delete p[path];
        delete s[path];
        win.pending = p;
        win.steps = s;
    }

    // turning goes with what is on screen: a flip after a quarter turn flips
    // the picture as it now lies
    function turn(dir) {
        if (!win.canTurn)
            return ;

        var e = win.edits;
        var crop = e.crop ? {
            "x": dir > 0 ? 1 - e.crop.y - e.crop.h : e.crop.y,
            "y": dir > 0 ? e.crop.x : 1 - e.crop.x - e.crop.w,
            "w": e.crop.h,
            "h": e.crop.w
        } : null;
        var flips = e.flipH !== e.flipV;
        win.change({
            "turns": (e.turns + (flips ? -dir : dir) + 4) % 4,
            "crop": crop
        });
    }

    function flip(horizontal) {
        if (!win.canEdit)
            return ;

        var e = win.edits;
        var crop = e.crop ? (horizontal ? {
            "x": 1 - e.crop.x - e.crop.w,
            "y": e.crop.y,
            "w": e.crop.w,
            "h": e.crop.h
        } : {
            "x": e.crop.x,
            "y": 1 - e.crop.y - e.crop.h,
            "w": e.crop.w,
            "h": e.crop.h
        }) : null;
        // a mirror turns a straightened picture the other way
        win.change(horizontal ? {
            "flipH": !e.flipH,
            "crop": crop,
            "angle": -e.angle
        } : {
            "flipV": !e.flipV,
            "crop": crop,
            "angle": -e.angle
        });
    }

    function openEditor(which) {
        // a video's edit is a trim; it has no crop or drawing
        if (win.isVideo) {
            if (which !== "crop" && which !== "markup")
                win.startTrim();

            return ;
        }
        if (!win.canEdit) {
            if (win.current && win.current.animated)
                win.say("Moving pictures can't be edited yet");

            return ;
        }
        win.overview = false;
        win.stopSlideshow();
        win.tab = which || win.tab;
        win.mode = "edit";
    }

    function keysBack() {
        keys.forceActiveFocus();
    }

    function closeEditor() {
        win.settled();
        win.draft = null;
        win.mode = "view";
        keys.forceActiveFocus();
    }

    // ---- saving

    function geometryOnly(e) {
        if (e.angle || (e.marks && e.marks.length))
            return false;

        for (var k in e.adjust || {}) {
            if (e.adjust[k])
                return false;

        }
        return true;
    }

    function save(copy) {
        var c = win.current, e = win.edits;
        if (!c || win.busy)
            return ;

        if (!win.dirty && !copy)
            return ;

        win.settled();
        var pic = stage.current;
        var req = {
            "src": c.path,
            "copy": copy === true || win.pasted,
            "alpha": c.canAlpha && (!win.info || win.info.alpha !== false),
            "fallback": win.app.caps.pictures || ""
        };
        if (win.pasted)
            req.folder = win.app.caps.pictures || "";

        win.busy = true;
        // a video only turns, by the note in it
        if (c.video) {
            win.app.call("turnVideo", {
                "src": c.path,
                "turns": e.turns,
                "copy": copy === true
            }, win.saved);
            return ;
        }
        if (win.geometryOnly(e) && !c.decoded && !c.vector) {
            var natW = pic ? pic.natW : 0, natH = pic ? pic.natH : 0;
            var fw = e.turns % 2 ? natH : natW, fh = e.turns % 2 ? natW : natH;
            req.turns = e.turns;
            req.flipH = e.flipH;
            req.flipV = e.flipV;
            req.crop = e.crop ? [e.crop.x * fw, e.crop.y * fh, e.crop.w * fw, e.crop.h * fh] : null;
            win.app.call("transform", req, win.saved);
            return ;
        }
        // drawn by qt at full size, then written by the daemon with the original's details
        var wasCrop = win.tab === "crop" && win.mode === "edit";
        if (wasCrop)
            win.tab = "adjust";

        grabLater.req = req;
        grabLater.restart();
    }

    Timer {
        id: grabLater

        property var req: null

        interval: 60
        onTriggered: {
            var pic = stage.current, req = grabLater.req;
            if (!pic || !pic.ready) {
                win.busy = false;
                win.say("The picture isn't ready yet");
                return ;
            }
            var tmp = win.app.home + "/.cache/lucid/lens/render-" + Date.now() + ".tiff";
            Quickshell.execDetached(["mkdir", "-p", win.app.home + "/.cache/lucid/lens"]);
            var ok = pic.grabToImage(function(r) {
                if (!r.saveToFile(tmp)) {
                    win.busy = false;
                    win.say("Couldn't draw the edited picture");
                    return ;
                }
                req.tmp = tmp;
                win.app.call("render", req, win.saved);
            }, Qt.size(Math.round(pic.width), Math.round(pic.height)));
            if (!ok) {
                win.busy = false;
                win.say("Couldn't draw the edited picture");
            }
        }
    }

    function saved(r) {
        win.busy = false;
        var c = win.current;
        if (!r.ok) {
            win.say(r.error || "Couldn't save it");
            return ;
        }
        if (c)
            win.forget(c.path);

        var name = win.app.nameOf(r.path);
        if (r.copy) {
            win.landOn = r.path;
            if (win.picked || win.pasted || win.app.parentOf(r.path) !== win.folder) {
                win.raw = win.raw.concat([{
                    "name": name,
                    "path": r.path,
                    "size": r.size,
                    "mtime": r.mtime,
                    "mime": "",
                    "desc": "",
                    "thumb": ""
                }]);
                if (win.pasted) {
                    win.pasted = false;
                    win.picked = true;
                }
                win.rebuild();
            }
            win.say("Saved as “" + name + "”", "Show", {
                "kind": "show",
                "path": r.path
            });
        } else {
            win.rewritten(r);
            // the first save over a picture is when lens files its original away
            var said = r.lossless ? "Saved, without losing any quality" : "Saved";
            if (r.first)
                said = r.lossless ? "Saved without losing quality  ·  original kept" : "Saved  ·  original kept";

            win.say(said, r.backup ? "Undo" : "", r.backup ? {
                "kind": "unsave",
                "path": r.path,
                "backup": r.backup,
                "first": r.first === true
            } : null);
        }
        if (win.mode === "edit")
            win.closeEditor();

    }

    // a picture lens wrote again: its new size and date, its thumbnail drawn
    // again, and its details read anew
    function rewritten(r) {
        win._revs[r.path] = win._revNext++;
        // a still made of the old file (a video's first frame) is made again
        var had = win._byPath[r.path];
        if (had && had.decoded)
            win._byPath[r.path] = Object.assign({}, had, {
            "decoded": "",
            "display": ""
        });

        win.raw = win.raw.map(function(it) {
            return it.path === r.path ? Object.assign({}, it, {
                "size": r.size,
                "mtime": r.mtime,
                "thumb": ""
            }) : it;
        });
        win.rebuild();
        for (var i = 0; i < strip.count; i++) {
            if (strip.get(i).path === r.path) {
                strip.setProperty(i, "rev", win._revs[r.path]);
                break;
            }
        }
        if (win.current && win.current.path === r.path)
            infoLater.restart();

    }

    // its original gone from the details at once, not when they are next read
    function clearKept(path) {
        if (win.info && win.info.path === path)
            win.info = Object.assign({}, win.info, {
            "original": null
        });

    }

    // ---- what can be done with a picture

    function say(text, action, payload) {
        snack.show(text, action, payload);
    }

    function acted(p) {
        if (!p)
            return ;

        if (p.kind === "unsave") {
            win.app.call("undoSave", {
                "path": p.path,
                "backup": p.backup,
                "first": p.first === true
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Couldn't put it back");
                    return ;
                }
                if (p.first)
                    win.clearKept(r.path);

                win.rewritten(r);
                win.say("Put back as it was");
            });
        } else if (p.kind === "unrevert") {
            win.app.call("unrevert", {
                "path": p.path,
                "backup": p.backup,
                "entry": p.entry
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Couldn't put the edits back");
                    return ;
                }
                win.rewritten(r);
                win.say("Edited version put back");
            });
        } else if (p.kind === "restore") {
            win.app.call("restore", {
                "path": p.path
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Couldn't restore it");
                    return ;
                }
                win.landOn = p.path;
                if (win.picked)
                    win.raw = win.raw.concat([p.entry]);

                win.rebuild();
                win.say("Restored “" + win.app.nameOf(p.path) + "”");
            });
        } else if (p.kind === "wallpaper") {
            win.app.call("wallpaper", {
                "path": p.previous
            });
            win.say("Wallpaper put back");
        } else if (p.kind === "show") {
            win.reveal(p.path);
        } else if (p.kind === "jump") {
            // made beside the one on show: go to it; anywhere else, lumen shows it
            var at = -1;
            for (var i = 0; i < win.items.length; i++) {
                if (win.items[i].path === p.path)
                    at = i;

            }
            if (at >= 0)
                win.jump(at);
            else
                win.reveal(p.path);
        }
    }

    function trash() {
        var c = win.current;
        if (!c || win.pasted)
            return ;

        var go = function() {
            var entry = win.raw.filter(function(it) {
                return it.path === c.path;
            })[0];
            win.app.call("trash", {
                "path": c.path
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Couldn't move it to the trash");
                    return ;
                }
                win.forget(c.path);
                win.raw = win.raw.filter(function(it) {
                    return it.path !== c.path;
                });
                win.rebuild();
                win.say("Moved “" + c.name + "” to the trash", "Undo", {
                    "kind": "restore",
                    "path": c.path,
                    "entry": entry
                });
            });
        };
        if (!win.app.prefs.confirmTrash) {
            go();
            return ;
        }
        dialog.ask({
            "title": "Move “" + c.name + "” to the trash?",
            "text": "It can be brought back from the trash later.",
            "confirm": "Move to trash",
            "danger": true
        }, function(ok) {
            if (ok)
                go();

        });
    }

    // the picture back as it was before lens first saved over it. asked first:
    // every saved edit goes, though the snackbar's undo brings them back
    function revertOriginal() {
        var c = win.current, k = win.kept;
        if (!c || !k || win.busy)
            return ;

        var text = "It goes back to how it was before your first saved edit, " + win.app.whenText(k.at) + ".";
        if (k.changed)
            text += " It has been changed by something else since then, and that goes too.";

        if (win.dirty)
            text += " So do the edits you haven't saved.";

        dialog.ask({
            "title": "Revert to the original?",
            "text": text,
            "confirm": "Revert",
            "glyph": k.thumb ? {
                "slot": "image",
                "thumb": k.thumb
            } : null
        }, function(ok) {
            if (ok)
                win.revertNow(c.path);

        });
    }

    function revertNow(path) {
        win.busy = true;
        win.app.call("revert", {
            "path": path
        }, function(r) {
            win.busy = false;
            if (!r.ok) {
                win.say(r.error || "Couldn't revert it");
                return ;
            }
            win.forget(path);
            win.clearKept(path);
            win.rewritten(r);
            win.say("Back to the original", "Undo", {
                "kind": "unrevert",
                "path": r.path,
                "backup": r.backup,
                "entry": r.entry
            });
        });
    }

    // the kept original let go, to the trash: the picture stays as it is, for good
    function dropOriginal() {
        var c = win.current, k = win.kept;
        if (!c || !k)
            return ;

        dialog.ask({
            "title": "Delete the original?",
            "text": "“" + c.name + "” stays as it is now, and Lens can't revert it any more. The original goes to the trash, freeing " + win.app.sizeText(k.size) + ".",
            "confirm": "Delete",
            "danger": true
        }, function(ok) {
            if (!ok)
                return ;

            win.app.call("forget", {
                "path": c.path
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Couldn't delete it");
                    return ;
                }
                win.clearKept(c.path);
                win.say("Original moved to the trash");
            });
        });
    }

    function rename() {
        var c = win.current;
        if (!c || win.pasted)
            return ;

        var dot = c.name.lastIndexOf(".");
        dialog.ask({
            "mode": "input",
            "title": "Rename",
            "input": c.name,
            "selectEnd": dot > 0 ? dot : c.name.length,
            "confirm": "Rename",
            "taken": win.raw.map(function(it) {
                return it.name;
            }).filter(function(n) {
                return n !== c.name;
            })
        }, function(ok, name) {
            if (!ok || name === c.name)
                return ;

            win.app.call("rename", {
                "path": c.path,
                "name": name
            }, function(r) {
                if (!r.ok) {
                    win.say(r.error || "Couldn't rename it");
                    return ;
                }
                var p = Object.assign({}, win.pending);
                if (p[c.path]) {
                    p[r.path] = p[c.path];
                    delete p[c.path];
                    win.pending = p;
                }
                win.raw = win.raw.map(function(it) {
                    return it.path === c.path ? Object.assign({}, it, {
                        "name": r.name,
                        "path": r.path,
                        "thumb": ""
                    }) : it;
                });
                win.landOn = r.path;
                win.rebuild();
                // its details, and its kept original, go by the new name
                infoLater.restart();
            });
        });
    }

    function setWallpaper() {
        var c = win.current;
        if (!c)
            return ;

        win.app.call("wallpaper", {
            "path": c.video ? c.path : (c.decoded || c.path)
        }, function(r) {
            if (!r.ok) {
                win.say(r.error || "Couldn't set the wallpaper");
                return ;
            }
            win.say("Wallpaper set", r.previous ? "Undo" : "", r.previous ? {
                "kind": "wallpaper",
                "previous": r.previous
            } : null);
        });
    }

    function copyImage() {
        var c = win.current;
        if (!c)
            return ;

        if (c.video) {
            win.app.call("copyFile", {
                "path": c.path
            });
            win.say("Video copied");
            return ;
        }
        win.app.call("copyImage", {
            "path": c.decoded || c.path
        }, function(r) {
            win.say(r.ok ? "Picture copied" : (r.error || "Couldn't copy it"));
        });
    }

    function copyPath() {
        var c = win.current;
        if (!c)
            return ;

        Quickshell.execDetached(["wl-copy", c.path]);
        win.say("Path copied");
    }

    function readText() {
        var c = win.current;
        if (!c)
            return ;

        win.say("Reading the text…");
        win.app.call("ocr", {
            "path": c.decoded || c.path
        }, function(r) {
            if (!r.ok)
                win.say(r.error || "Couldn't read it");
            else if (r.words === 0)
                win.say("There's no text to read in it");
            else
                win.say("Copied " + r.words + (r.words === 1 ? " word" : " words") + " of text");
        });
    }

    function reveal(path) {
        var at = win.app.caps.lumen || "";
        if (at !== "")
            Quickshell.execDetached([at, path]);
        else
            Quickshell.execDetached(["xdg-open", win.app.parentOf(path)]);
    }

    function openWith() {
        var c = win.current;
        if (!c)
            return ;

        win.app.call("appsFor", {
            "path": c.path
        }, function(r) {
            if (!r.ok || r.apps.length === 0) {
                win.say("No other app opens this kind of picture");
                return ;
            }
            dialog.ask({
                "mode": "apps",
                "title": "Open “" + c.name + "” with",
                "apps": r.apps,
                "confirm": "Open"
            }, function(ok, v) {
                if (!ok || !v || !v.app)
                    return ;

                win.app.call("openWith", {
                    "app": v.app.id,
                    "path": c.path,
                    "mime": r.mime,
                    "makeDefault": v.always
                });
            });
        });
    }

    function sendTo(device) {
        var c = win.current;
        if (!c)
            return ;

        win.app.call("send", {
            "device": device.id,
            "path": c.video ? c.path : (c.decoded || c.path)
        }, function(r) {
            win.say(r.ok ? "Sent to " + device.name : (r.error || "Couldn't send it"));
        });
    }

    function paste() {
        win.app.call("paste", {
        }, function(r) {
            if (!r.ok) {
                win.say(r.error || "There's no picture on the clipboard");
                return ;
            }
            if (!win.confirmLeave(function() {
                win.openFiles(r.paths, r.pasted === true);
            }))
                return ;

            win.openFiles(r.paths, r.pasted === true);
        });
    }

    function openFiles(paths, isPaste) {
        win.pending = ({});
        win.steps = ({});
        win.mode = "view";
        win.overview = false;
        win.pasted = isPaste === true;
        win.raw = [];
        win.items = [];
        win.index = -1;
        win.load(paths.join("\n"));
    }

    function pickFile() {
        picker.running = true;
    }

    // unsaved edits are only lost on purpose: true when there are none to lose
    function confirmLeave(then) {
        if (win.dirtyCount === 0)
            return true;

        dialog.ask({
            "title": win.dirtyCount === 1 ? "Discard your edits?" : "Discard edits to " + win.dirtyCount + " pictures?",
            "text": "They haven't been saved.",
            "confirm": "Discard",
            "danger": true
        }, function(ok) {
            if (ok) {
                win.pending = ({});
                win.steps = ({});
                then();
            }
        });
        return false;
    }

    function leave() {
        if (!win.confirmLeave(function() {
            win.leave();
        }))
            return ;

        win.visible = false;
        win.app.closeWindow(win.winId);
    }

    // ---- slideshow and full screen

    function startSlideshow() {
        if (win.items.length < 2)
            return ;

        win.mode = "view";
        win.overview = false;
        win.slideshow = true;
        win.slidePaused = false;
        win.setImmersive(true);
        stage.fit();
        win.nextSlideLater();
    }

    function stopSlideshow() {
        if (!win.slideshow)
            return ;

        win.slideshow = false;
        slideTimer.stop();
        win.setImmersive(false);
    }

    function setImmersive(on) {
        win.immersive = on;
        var w = root.Window.window;
        if (w)
            w.visibility = on ? Window.FullScreen : Window.Windowed;

    }

    function pauseSlideshow(p) {
        win.slidePaused = p;
        if (stage.movie) {
            if (p)
                stage.movie.player.pause();
            else
                stage.movie.play();
        }
        if (!p)
            win.nextSlideLater();

    }

    // the clock for the next slide starts again; a video keeps it stopped, and
    // moves the slideshow on itself when it has played out
    function nextSlideLater() {
        if (win.slideshow && !win.slidePaused && !win.isVideo)
            slideTimer.restart();
        else
            slideTimer.stop();
    }

    function nextSlide() {
        if (win.app.prefs.shuffle && win.items.length > 2) {
            var r = win.index;
            while (r === win.index)r = Math.floor(Math.random() * win.items.length)
            win.index = r;
        } else {
            stage.go(1);
        }
    }

    Timer {
        id: slideTimer

        interval: Math.max(2, win.app.prefs.slideSecs) * 1000
        repeat: true
        // a video holds the slideshow until it has played out
        running: win.slideshow && !win.slidePaused && !win.isVideo
        onTriggered: win.nextSlide()
    }

    // ---- videos

    function setVolume(v) {
        var p = win.app.prefs;
        p.volume = Math.max(0, Math.min(1, Math.round(v * 100) / 100));
        p.muted = p.volume <= 0;
    }

    function rateText(r) {
        return String(r) + "×";
    }

    function rateMenu(x, y) {
        menu.open([{
            "heading": "Speed"
        }].concat([0.25, 0.5, 0.75, 1, 1.25, 1.5, 2].map(function(r) {
            return {
                "id": "rate:" + r,
                "label": r === 1 ? "Normal" : win.rateText(r),
                "radio": true,
                "checked": win.rate === r
            };
        })), x, y, win.run);
    }

    // the frame on show, at its full size: a picture beside the video, or the clipboard
    function saveFrame() {
        var c = win.current;
        if (!c || !c.video)
            return ;

        win.app.call("frame", {
            "path": c.path,
            "at": stage.movie ? stage.movie.position / 1000 : 0
        }, function(r) {
            if (!r.ok) {
                win.say(r.error || "Couldn't save that frame");
                return ;
            }
            win.say("Saved “" + r.name + "”", "Show", {
                "kind": "jump",
                "path": r.path
            });
        });
    }

    function copyFrame() {
        var c = win.current;
        if (!c || !c.video)
            return ;

        win.app.call("frame", {
            "path": c.path,
            "at": stage.movie ? stage.movie.position / 1000 : 0,
            "clipboard": true
        }, function(r) {
            win.say(r.ok ? "Frame copied" : (r.error || "Couldn't copy that frame"));
        });
    }

    // ---- trimming a video: Trimmer.qml sets the span, the daemon cuts a copy

    property string trimJob: ""
    // how far a cut has got, 0 to 1
    property real trimDone: 0

    function startTrim() {
        if (!win.isVideo || win.current.broken)
            return ;

        win.stopSlideshow();
        win.overview = false;
        win.trimming = true;
    }

    function closeTrim() {
        if (win.trimJob !== "")
            win.app.call("cancel", {
            "job": win.trimJob
        });

        win.trimming = false;
        keys.forceActiveFocus();
    }

    function saveTrim(from, to, exact) {
        var c = win.current;
        if (!c || win.trimJob !== "")
            return ;

        var job = "trim-" + win.winId + "-" + Date.now();
        win.trimJob = job;
        win.trimDone = 0;
        win.app.call("trim", {
            "src": c.path,
            "start": from / 1000,
            "end": to / 1000,
            "exact": exact,
            "job": job
        }, function(r) {
            win.trimJob = "";
            if (!r.ok) {
                win.say(r.error === "Stopped" ? "Trim stopped" : (r.error || "Couldn't trim it"));
                return ;
            }
            win.trimming = false;
            keys.forceActiveFocus();
            win.say("Saved “" + r.name + "”", "Show", {
                "kind": "jump",
                "path": r.path
            });
        });
    }

    // ---- menus

    function pictureMenu(x, y) {
        var c = win.current;
        if (!c)
            return ;

        if (c.video) {
            win.videoMenu(x, y);
            return ;
        }
        var caps = win.app.caps;
        var items = [{
            "id": "openWith",
            "label": "Open with…",
            "icon": "apps"
        }, caps.lumen ? {
            "id": "reveal",
            "label": "Show in Lumen",
            "icon": "folder_open"
        } : null, {
            "sep": true
        }, caps.wallpaper ? {
            "id": "wallpaper",
            "label": "Set as wallpaper",
            "icon": "wallpaper"
        } : null, {
            "id": "copy",
            "label": "Copy picture",
            "icon": "content_copy",
            "hint": "Ctrl+C"
        }, {
            "id": "copyPath",
            "label": "Copy path",
            "icon": "link",
            "hint": "Ctrl+Shift+C"
        }, {
            "id": "pick",
            "label": "Pick a colour",
            "icon": "colorize",
            "hint": "P"
        }, caps.ocr ? {
            "id": "ocr",
            "label": "Copy text in it",
            "icon": "document_scanner"
        } : null, caps.phone ? {
            "id": "phone",
            "label": "Send to phone…",
            "icon": "send_to_mobile"
        } : null, {
            "sep": true
        }, {
            "id": "turnLeft",
            "label": "Rotate left",
            "icon": "rotate_left",
            "hint": "Shift+R",
            "disabled": !win.canEdit
        }, {
            "id": "turnRight",
            "label": "Rotate right",
            "icon": "rotate_right",
            "hint": "R",
            "disabled": !win.canEdit
        }, {
            "id": "edit",
            "label": "Edit",
            "icon": "tune",
            "hint": "E",
            "disabled": !win.canEdit
        }, {
            "id": "markup",
            "label": "Draw on it",
            "icon": "draw",
            "hint": "D",
            "disabled": !win.canEdit
        }, win.kept ? {
            "id": "revert",
            "label": "Revert to original",
            "icon": "history",
            "disabled": win.busy
        } : null, {
            "sep": true
        }, {
            "id": "rename",
            "label": "Rename…",
            "icon": "edit",
            "hint": "F2",
            "disabled": win.pasted
        }, {
            "id": "trash",
            "label": "Move to trash",
            "icon": "delete",
            "hint": "Delete",
            "danger": true,
            "disabled": win.pasted
        }, {
            "sep": true
        }, {
            "id": "info",
            "label": win.showInfo ? "Hide details" : "Details",
            "icon": "info",
            "hint": "I"
        }];
        menu.open(items.filter(function(it) {
            return it !== null;
        }), x, y, win.run);
    }

    function videoMenu(x, y) {
        var c = win.current, caps = win.app.caps;
        var items = [{
            "id": "openWith",
            "label": "Open with…",
            "icon": "apps"
        }, caps.lumen ? {
            "id": "reveal",
            "label": "Show in Lumen",
            "icon": "folder_open"
        } : null, {
            "sep": true
        }, caps.wallpaper && win.app.liveKind(c.path) ? {
            "id": "wallpaper",
            "label": "Set as wallpaper",
            "icon": "wallpaper"
        } : null, {
            "id": "copy",
            "label": "Copy video",
            "icon": "content_copy",
            "hint": "Ctrl+C"
        }, {
            "id": "copyFrame",
            "label": "Copy this frame",
            "icon": "image"
        }, {
            "id": "saveFrame",
            "label": "Save this frame as a picture",
            "icon": "photo_camera"
        }, {
            "id": "copyPath",
            "label": "Copy path",
            "icon": "link",
            "hint": "Ctrl+Shift+C"
        }, caps.phone ? {
            "id": "phone",
            "label": "Send to phone…",
            "icon": "send_to_mobile"
        } : null, {
            "sep": true
        }, win.canTurn ? {
            "id": "turnLeft",
            "label": "Rotate left",
            "icon": "rotate_left",
            "hint": "Shift+R"
        } : null, win.canTurn ? {
            "id": "turnRight",
            "label": "Rotate right",
            "icon": "rotate_right",
            "hint": "R"
        } : null, {
            "id": "trim",
            "label": "Trim…",
            "icon": "content_cut",
            "hint": "E",
            "disabled": c.broken === true
        }, win.kept ? {
            "id": "revert",
            "label": "Revert to original",
            "icon": "history",
            "disabled": win.busy
        } : null, {
            "sep": true
        }, {
            "id": "rename",
            "label": "Rename…",
            "icon": "edit",
            "hint": "F2"
        }, {
            "id": "trash",
            "label": "Move to trash",
            "icon": "delete",
            "hint": "Delete",
            "danger": true
        }, {
            "sep": true
        }, {
            "id": "info",
            "label": win.showInfo ? "Hide details" : "Details",
            "icon": "info",
            "hint": "I"
        }];
        menu.open(items.filter(function(it) {
            return it !== null;
        }), x, y, win.run);
    }

    function moreMenu(x, y) {
        var p = win.app.prefs;
        var items = [{
            "id": "slideshow",
            "label": "Slideshow",
            "icon": "slideshow",
            "hint": "F5",
            "disabled": win.items.length < 2
        }, {
            "id": "fullscreen",
            "label": win.immersive ? "Leave full screen" : "Full screen",
            "icon": win.immersive ? "fullscreen_exit" : "fullscreen",
            "hint": "F"
        }, {
            "id": "overview",
            "label": "All pictures",
            "icon": "grid_view",
            "hint": "G"
        }, {
            "id": "strip",
            "label": "Filmstrip",
            "icon": "view_carousel",
            "hint": "T",
            "checked": p.filmstrip
        }, {
            "sep": true
        }, {
            "id": "background",
            "label": "Background",
            "icon": "palette",
            "sub": [{
                "id": "bg:theme",
                "label": "Lucid",
                "radio": true,
                "checked": p.background === "theme"
            }, {
                "id": "bg:dark",
                "label": "Dark",
                "radio": true,
                "checked": p.background === "dark"
            }, {
                "id": "bg:black",
                "label": "Black",
                "radio": true,
                "checked": p.background === "black"
            }, {
                "sep": true
            }, {
                "id": "checker",
                "label": "Checks behind see-through parts",
                "checked": p.checker
            }]
        }, {
            "id": "wheel",
            "label": "Mouse wheel",
            "icon": "zoom_in",
            "sub": [{
                "id": "wheel:zoom",
                "label": "Zooms",
                "radio": true,
                "checked": p.wheel === "zoom"
            }, {
                "id": "wheel:browse",
                "label": "Goes to the next picture",
                "radio": true,
                "checked": p.wheel === "browse"
            }]
        }, {
            "id": "slideOpts",
            "label": "Slideshow",
            "icon": "timer",
            "sub": [3, 5, 10, 20, 60].map(function(s) {
                return {
                    "id": "secs:" + s,
                    "label": s < 60 ? s + " seconds each" : "A minute each",
                    "radio": true,
                    "checked": p.slideSecs === s
                };
            }).concat([{
                "sep": true
            }, {
                "id": "shuffle",
                "label": "Shuffle",
                "checked": p.shuffle
            }])
        }, (win.app.caps.videos || []).length > 0 ? {
            "id": "videoOpts",
            "label": "Videos",
            "icon": "movie",
            "sub": [{
                "id": "videos",
                "label": "Show them with the pictures",
                "checked": p.videos
            }, {
                "id": "autoplay",
                "label": "Play one when it's shown",
                "checked": p.autoplay
            }, {
                "id": "loopVideos",
                "label": "Play them round and round",
                "checked": p.loopVideos
            }]
        } : null, {
            "id": "wrap",
            "label": "Go round from the last to the first",
            "icon": "repeat",
            "checked": p.wrap
        }, {
            "sep": true
        }, {
            "id": "open",
            "label": "Open…",
            "icon": "folder_open",
            "hint": "Ctrl+O"
        }, {
            "id": "paste",
            "label": "Paste a picture",
            "icon": "content_paste",
            "hint": "Ctrl+V"
        }, {
            "id": "keys",
            "label": "Keyboard shortcuts",
            "icon": "keyboard",
            "hint": "?"
        }];
        menu.open(items.filter(function(it) {
            return it !== null;
        }), x, y, win.run);
    }

    function zoomMenu(x, y) {
        var levels = [0.25, 0.5, 1, 2, 4];
        menu.open([{
            "id": "zoom:fit",
            "label": "Fit to window",
            "icon": "fit_screen",
            "hint": "0",
            "radio": false
        }].concat(levels.map(function(z) {
            return {
                "id": "zoom:" + z,
                "label": Math.round(z * 100) + "%",
                "hint": z === 1 ? "1" : ""
            };
        })), x, y, win.run);
    }

    function phoneMenu() {
        win.app.call("devices", {
        }, function(r) {
            var list = r.devices || [];
            if (list.length === 0) {
                win.say("No phone is connected right now");
                return ;
            }
            if (list.length === 1) {
                win.sendTo(list[0]);
                return ;
            }
            var p = stage.mapToItem(root, stage.width / 2 - Theme.dp(120), stage.height / 3);
            menu.open([{
                "heading": "Send to"
            }].concat(list.map(function(d) {
                return {
                    "id": "send:" + d.id,
                    "label": d.name,
                    "icon": "send_to_mobile",
                    "device": d
                };
            })), p.x, p.y, function(id, it) {
                if (it && it.device)
                    win.sendTo(it.device);

            });
        });
    }

    function run(id, it) {
        var p = win.app.prefs;
        if (id.indexOf("bg:") === 0) {
            p.background = id.slice(3);
            return ;
        }
        if (id.indexOf("wheel:") === 0) {
            p.wheel = id.slice(6);
            return ;
        }
        if (id.indexOf("secs:") === 0) {
            p.slideSecs = Number(id.slice(5));
            return ;
        }
        if (id.indexOf("rate:") === 0) {
            win.rate = Number(id.slice(5));
            return ;
        }
        if (id.indexOf("zoom:") === 0) {
            var z = id.slice(5);
            if (z === "fit")
                stage.fit();
            else
                stage.zoomTo(Number(z), undefined, undefined, true);
            return ;
        }
        switch (id) {
        case "openWith":
            win.openWith();
            break;
        case "reveal":
            if (win.current)
                win.reveal(win.current.path);

            break;
        case "wallpaper":
            win.setWallpaper();
            break;
        case "copy":
            win.copyImage();
            break;
        case "copyPath":
            win.copyPath();
            break;
        case "ocr":
            win.readText();
            break;
        case "pick":
            win.closeEditor();
            win.picking = true;
            break;
        case "phone":
            win.phoneMenu();
            break;
        case "turnLeft":
            win.turn(-1);
            break;
        case "turnRight":
            win.turn(1);
            break;
        case "edit":
            win.openEditor("adjust");
            break;
        case "markup":
            win.openEditor("markup");
            break;
        case "revert":
            win.revertOriginal();
            break;
        case "copyFrame":
            win.copyFrame();
            break;
        case "saveFrame":
            win.saveFrame();
            break;
        case "trim":
            win.startTrim();
            break;
        case "videos":
            p.videos = !p.videos;
            break;
        case "autoplay":
            p.autoplay = !p.autoplay;
            break;
        case "loopVideos":
            p.loopVideos = !p.loopVideos;
            break;
        case "rename":
            win.rename();
            break;
        case "trash":
            win.trash();
            break;
        case "info":
            win.showInfo = !win.showInfo;
            break;
        case "slideshow":
            win.startSlideshow();
            break;
        case "fullscreen":
            win.setImmersive(!win.immersive);
            break;
        case "overview":
            win.overview = !win.overview;
            break;
        case "strip":
            p.filmstrip = !p.filmstrip;
            break;
        case "checker":
            p.checker = !p.checker;
            break;
        case "shuffle":
            p.shuffle = !p.shuffle;
            break;
        case "wrap":
            p.wrap = !p.wrap;
            break;
        case "open":
            win.pickFile();
            break;
        case "paste":
            win.paste();
            break;
        case "keys":
            win.showKeys();
            break;
        }
    }

    function showKeys() {
        dialog.ask({
            "mode": "info",
            "title": "Keyboard shortcuts",
            "rows": [{
                "label": "← →",
                "value": "The previous and next picture (Home, End: the first and last)"
            }, {
                "label": "+  −  0  1",
                "value": "Zoom in, out, to fit, to 100%"
            }, {
                "label": "R  Shift+R",
                "value": "Rotate right, left"
            }, {
                "label": "E  C  D",
                "value": "Edit, crop, draw"
            }, {
                "label": "Ctrl+Z  Ctrl+Y",
                "value": "Undo, redo an edit"
            }, {
                "label": "Ctrl+S",
                "value": "Save (Ctrl+Shift+S: as a copy)"
            }, {
                "label": "I  T  G",
                "value": "Details, filmstrip, all pictures"
            }, {
                "label": "F  F5",
                "value": "Full screen, slideshow"
            }, {
                "label": "Ctrl+C",
                "value": "Copy the picture"
            }, {
                "label": "F2  Delete",
                "value": "Rename, move to the trash"
            }, {
                "label": "P",
                "value": "Pick a colour off the picture"
            }, {
                "label": "\\",
                "value": "Hold to compare with the original"
            }].concat((win.app.caps.videos || []).length === 0 ? [] : [{
                "label": "Space  K",
                "value": "Play or pause a video (E: trim it)"
            }, {
                "label": "J  L",
                "value": "Back or on ten seconds"
            }, {
                "label": ",  .",
                "value": "A frame back or on, paused"
            }, {
                "label": "M  ↑  ↓",
                "value": "Mute, louder, quieter"
            }])
        });
    }

    visible: true
    title: win.current ? win.current.name : "Lens"
    // one step under solid, so hyprland can still blur it
    color: win.immersive ? "black" : Theme.alpha(Theme.bg, Math.min(Theme.bg.a, 254 / 255))
    implicitWidth: Theme.dp(win.app.prefs.width)
    implicitHeight: Theme.dp(win.app.prefs.height)
    minimumSize.width: Theme.dp(520)
    minimumSize.height: Theme.dp(400)
    onClosed: {
        win.app.closeWindow(win.winId);
    }
    onWidthChanged: sizeLater.restart()
    onHeightChanged: sizeLater.restart()
    Component.onCompleted: {
        win.app.focusedWindow = win;
        win.load(win.startFiles);
        keys.forceActiveFocus();
    }

    Timer {
        id: sizeLater

        interval: 600
        onTriggered: {
            if (win.immersive)
                return ;

            win.app.prefs.width = Math.round(win.width / Theme.uiScale);
            win.app.prefs.height = Math.round(win.height / Theme.uiScale);
        }
    }

    ListModel {
        id: strip
    }

    Connections {
        // a window hears about every thumbnail in its folder as it opens, so this
        // stays cheap: only the pictures on the stage take theirs through a binding
        function onThumbEvent(path, thumb) {
            var e = win._byPath[path], row = win._rows[path];
            if (!e || row === undefined)
                return ;

            var off = Math.abs(row - win.index);
            if (off <= 1 || off === win.items.length - 1)
                win.setItem(path, {
                "thumb": thumb
            });
            else
                e.thumb = thumb;
            strip.setProperty(row, "thumb", thumb);
            strip.setProperty(row, "failed", thumb === "");
        }

        function onFolderEvent(ev) {
            if (win.picked || ev.path !== win.folder)
                return ;

            win.raw = ev.items;
            win.rebuild();
        }

        function onLumenRevChanged() {
            if (!win.picked)
                win.rebuild();

        }

        function onProgressEvent(job, t) {
            if (job === win.trimJob)
                win.trimDone = t;

        }

        target: win.app
    }

    Connections {
        function onVideosChanged() {
            win.rebuild();
        }

        target: win.app.prefs
    }

    Connections {
        function onEnded() {
            if (win.slideshow && !win.slidePaused)
                win.nextSlide();

        }

        target: stage.movie
        ignoreUnknownSignals: true
    }

    Process {
        id: picker

        command: ["python3", Qt.resolvedUrl("../lucidprefs/pickfile.py").toString().replace("file://", ""), "--title", "Open a picture", "--filter", "Pictures=image/*", "--file", win.folder || win.app.home]

        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim().split("\n")[0] || "";
                if (p === "")
                    return ;

                if (!win.confirmLeave(function() {
                    win.openFiles([p]);
                }))
                    return ;

                win.openFiles([p]);
            }
        }

    }

    Shortcut {
        sequences: ["Ctrl+W", "Ctrl+Q"]
        onActivated: win.leave()
    }

    Shortcut {
        sequences: ["Ctrl+Z"]
        enabled: !dialog.shown
        onActivated: win.undo()
    }

    Shortcut {
        sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]
        enabled: !dialog.shown
        onActivated: win.redo()
    }

    Shortcut {
        sequences: ["Ctrl+S"]
        enabled: !dialog.shown
        onActivated: win.save(false)
    }

    Shortcut {
        sequences: ["Ctrl+Shift+S"]
        enabled: !dialog.shown
        onActivated: win.save(true)
    }

    Shortcut {
        sequences: ["Ctrl+C"]
        enabled: !dialog.shown && !drawPad.typing && !win.overview
        onActivated: win.copyImage()
    }

    Shortcut {
        sequences: ["Ctrl+Shift+C"]
        enabled: !dialog.shown
        onActivated: win.copyPath()
    }

    Shortcut {
        sequences: ["Ctrl+V"]
        enabled: !dialog.shown && !drawPad.typing && !win.overview
        onActivated: win.paste()
    }

    Shortcut {
        sequences: ["Ctrl+O"]
        enabled: !dialog.shown
        onActivated: win.pickFile()
    }

    Shortcut {
        sequences: ["F11"]
        onActivated: win.setImmersive(!win.immersive)
    }

    Shortcut {
        sequences: ["F5"]
        onActivated: win.slideshow ? win.stopSlideshow() : win.startSlideshow()
    }

    Shortcut {
        sequences: ["F2"]
        enabled: !dialog.shown
        onActivated: win.rename()
    }

    Shortcut {
        sequences: ["Ctrl+I", "Alt+Return"]
        onActivated: win.showInfo = !win.showInfo
    }

    Item {
        id: root

        anchors.fill: parent

        // offscreen grabs drop the window's own colour; the rig paints it in
        Rectangle {
            anchors.fill: parent
            visible: (Quickshell.env("LENS_SHOT") || "") !== ""
            color: win.immersive ? "black" : Theme.bgOpaque
        }

        // the keys of a viewer: one letter each, while nothing is being typed
        Item {
            id: keys

            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                var k = event.key, mods = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
                var shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                if (mods) {
                    if ((event.modifiers & Qt.ControlModifier) && (k === Qt.Key_Equal || k === Qt.Key_Plus)) {
                        stage.zoomBy(1.25);
                        event.accepted = true;
                    } else if ((event.modifiers & Qt.ControlModifier) && k === Qt.Key_Minus) {
                        stage.zoomBy(0.8);
                        event.accepted = true;
                    } else if ((event.modifiers & Qt.ControlModifier) && k === Qt.Key_0) {
                        stage.fit();
                        event.accepted = true;
                    }
                    return ;
                }
                event.accepted = true;
                switch (k) {
                case Qt.Key_Right:
                case Qt.Key_PageDown:
                case Qt.Key_Space:
                    if (k === Qt.Key_Space && win.slideshow) {
                        win.pauseSlideshow(!win.slidePaused);
                    } else if (k === Qt.Key_Space && stage.movie) {
                        stage.movie.toggle();
                    } else if (stage.canPan && k === Qt.Key_Right && !shift) {
                        stage.panX -= Theme.dp(120);
                        stage.clampPan();
                    } else {
                        win.go(1);
                    }
                    break;
                case Qt.Key_Left:
                case Qt.Key_PageUp:
                case Qt.Key_Backspace:
                    if (stage.canPan && k === Qt.Key_Left && !shift) {
                        stage.panX += Theme.dp(120);
                        stage.clampPan();
                    } else {
                        win.go(-1);
                    }
                    break;
                case Qt.Key_Up:
                    if (stage.canPan) {
                        stage.panY += Theme.dp(120);
                        stage.clampPan();
                    } else if (win.isVideo) {
                        win.setVolume(win.app.prefs.volume + 0.05);
                    }
                    break;
                case Qt.Key_Down:
                    if (stage.canPan) {
                        stage.panY -= Theme.dp(120);
                        stage.clampPan();
                    } else if (win.isVideo) {
                        win.setVolume(win.app.prefs.volume - 0.05);
                    }
                    break;
                // a video: play and pause, ten seconds back and on, a frame at a time, quiet
                case Qt.Key_K:
                    if (stage.movie)
                        stage.movie.toggle();
                    break;
                case Qt.Key_J:
                case Qt.Key_L:
                    if (stage.movie)
                        stage.movie.skip(k === Qt.Key_J ? -10000 : 10000);
                    break;
                case Qt.Key_Comma:
                case Qt.Key_Period:
                    if (stage.movie)
                        stage.movie.step(k === Qt.Key_Comma ? -1 : 1);
                    break;
                case Qt.Key_M:
                    if (win.isVideo)
                        win.app.prefs.muted = !win.app.prefs.muted;
                    break;
                case Qt.Key_Home:
                    win.jump(0);
                    break;
                case Qt.Key_End:
                    win.jump(win.items.length - 1);
                    break;
                case Qt.Key_Plus:
                case Qt.Key_Equal:
                    stage.zoomBy(1.25);
                    break;
                case Qt.Key_Minus:
                    stage.zoomBy(0.8);
                    break;
                case Qt.Key_0:
                    stage.fit();
                    break;
                case Qt.Key_1:
                    stage.zoomTo(1, undefined, undefined, true);
                    break;
                case Qt.Key_2:
                    stage.zoomTo(2, undefined, undefined, true);
                    break;
                case Qt.Key_R:
                    win.turn(shift ? -1 : 1);
                    break;
                case Qt.Key_E:
                    if (win.mode === "edit")
                        win.closeEditor();
                    else
                        win.openEditor("adjust");
                    break;
                case Qt.Key_C:
                    win.openEditor("crop");
                    break;
                case Qt.Key_D:
                    win.openEditor("markup");
                    break;
                case Qt.Key_I:
                    win.showInfo = !win.showInfo;
                    break;
                case Qt.Key_T:
                    win.app.prefs.filmstrip = !win.app.prefs.filmstrip;
                    break;
                case Qt.Key_G:
                    win.overview = !win.overview;
                    break;
                case Qt.Key_F:
                    win.setImmersive(!win.immersive);
                    break;
                case Qt.Key_S:
                    if (win.slideshow)
                        win.stopSlideshow();
                    else
                        win.startSlideshow();
                    break;
                case Qt.Key_Delete:
                    win.trash();
                    break;
                case Qt.Key_P:
                    if (win.mode === "view" && !win.isVideo)
                        win.picking = !win.picking;
                    break;
                case Qt.Key_Backslash:
                    if (win.dirty || win.kept)
                        win.comparing = true;
                    break;
                case Qt.Key_Question:
                    win.showKeys();
                    break;
                case Qt.Key_Escape:
                    win.stepBack();
                    break;
                default:
                    event.accepted = false;
                }
            }
            Keys.onReleased: (event) => {
                if (event.key === Qt.Key_Backslash && !event.isAutoRepeat) {
                    win.comparing = false;
                    event.accepted = true;
                }
            }
        }

        // the mouse's side buttons go back and forward through the folder
        MouseArea {
            anchors.fill: parent
            z: 300
            enabled: !menu.shown && !dialog.shown
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onPressed: (mouse) => {
                return win.go(mouse.button === Qt.BackButton ? -1 : 1);
            }
        }

        // pictures dropped on the window open in it
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: (drop) => {
                var list = (drop.urls || []).map(function(u) {
                    return win.app.normalise(u.toString());
                });
                if (list.length === 0)
                    return ;

                drop.accept(Qt.CopyAction);
                if (win.confirmLeave(function() {
                    win.openFiles(list);
                }))
                    win.openFiles(list);

            }
        }

        LensBar {
            id: bar

            win: win
            app: win.app
            stage: stage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.dp(64)
            anchors.topMargin: win.immersive ? -height : 0
            opacity: win.immersive ? 0 : 1

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        // the stage, in lucid's floating pane, its corners kept round when zoomed
        ClippingRectangle {
            id: sheet

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: win.edge
            anchors.rightMargin: win.edge + win.panelW
            anchors.topMargin: win.barH
            anchors.bottomMargin: win.edge + win.stripH + win.trimH
            radius: win.immersive ? 0 : Theme.shapeXl
            color: win.immersive || win.app.prefs.background === "black" ? "black" : win.app.prefs.background === "dark" ? Theme.isLight ? "#1d1d1f" : "#0d0d0e" : Theme.withBlur(Theme.bgSunken)

            Behavior on anchors.leftMargin {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            Behavior on anchors.topMargin {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durMedium
                }

            }

            Stage {
                id: stage

                win: win
                app: win.app
                anchors.fill: parent
                items: win.items
                index: win.index
                edits: win.edits
                cropping: win.mode === "edit" && win.tab === "crop"
                drawing: win.mode === "edit" && win.tab === "markup"
                locked: win.trimming
                original: win.comparing
                draft: win.draft
                wheelMode: win.app.prefs.wheel
                wrap: win.app.prefs.wrap || win.slideshow
                opacity: peek.shown ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }
                onNavigate: (delta) => {
                    var n = win.items.length;
                    win.index = (win.index + delta + n) % n;
                    if (win.slideshow)
                        win.nextSlideLater();

                }
                onMenuAt: (x, y) => {
                    var p = stage.mapToItem(root, x, y);
                    win.pictureMenu(p.x, p.y);
                }
                onTapped: {
                    if (win.slideshow)
                        win.pauseSlideshow(!win.slidePaused);

                }
            }

            Peek {
                id: peek

                anchors.fill: parent
                win: win
                stage: stage
            }

            CropTool {
                id: cropTool

                anchors.fill: parent
                win: win
                stage: stage
                active: win.mode === "edit" && win.tab === "crop" && stage.current !== null && stage.current.ready
            }

            DrawPad {
                id: drawPad

                anchors.fill: parent
                win: win
                stage: stage
                active: win.mode === "edit" && win.tab === "markup" && stage.current !== null && stage.current.ready
            }

            StageControls {
                anchors.fill: parent
                win: win
                stage: stage
            }

            ColourPicker {
                anchors.fill: parent
                win: win
                stage: stage
                active: win.picking && win.mode === "view" && !win.overview
            }


            Overview {
                id: overview

                win: win
                app: win.app
                model: strip
                anchors.fill: parent
            }

        }

        Filmstrip {
            id: filmstrip

            win: win
            app: win.app
            model: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(12) + win.panelW
            height: win.stripH
            visible: height > 1
            clip: true
        }

        Trimmer {
            id: trimmer

            win: win
            stage: stage
            active: win.trimming && win.isVideo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: win.edge
            anchors.rightMargin: win.edge + win.panelW
            anchors.bottomMargin: win.edge
            height: Math.max(0, win.trimH - Theme.dp(12))
            visible: height > 1
        }

        InfoPanel {
            id: infoPanel

            win: win
            app: win.app
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: win.barH
            anchors.bottomMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(12)
            width: Math.max(0, win.panelW - Theme.dp(12))
            visible: width > 1 && win.mode === "view"
        }

        EditPanel {
            id: editPanel

            win: win
            app: win.app
            stage: stage
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: win.barH
            anchors.bottomMargin: Theme.dp(12)
            anchors.rightMargin: Theme.dp(12)
            width: Math.max(0, win.panelW - Theme.dp(12))
            visible: width > 1 && win.mode === "edit"
        }

        Snackbar {
            id: snack

            z: 350
            onActed: (payload) => {
                return win.acted(payload);
            }
        }

        LumenMenu {
            id: menu

            z: 400
            onShownChanged: {
                if (!menu.shown && !dialog.shown)
                    keys.forceActiveFocus();

            }
        }

        LumenDialog {
            id: dialog

            z: 500
            onShownChanged: {
                if (!dialog.shown)
                    keys.forceActiveFocus();

            }
        }

    }

    // esc steps back out: the menu, the grid, the editor, full screen, then
    // the window itself
    function stepBack() {
        if (win.trimming) {
            win.closeTrim();
            return ;
        }
        if (win.picking) {
            win.picking = false;
            return ;
        }
        if (drawPad.typing) {
            drawPad.finishText();
            return ;
        }
        if (win.overview) {
            win.overview = false;
            return ;
        }
        if (win.slideshow) {
            win.stopSlideshow();
            return ;
        }
        if (win.mode === "edit") {
            if (win.tab === "crop" || win.tab === "markup")
                win.tab = "adjust";
            else
                win.closeEditor();
            return ;
        }
        if (win.immersive) {
            win.setImmersive(false);
            return ;
        }
        if (stage.zoomed) {
            stage.fit();
            return ;
        }
        if (win.app.prefs.escCloses)
            win.leave();

    }

    // the render rig's hook: LENS_RIG is a json list of steps to play before
    // the picture, so the editor and menus can be looked at without a screen
    Timer {
        interval: Number(Quickshell.env("LENS_RIG_MS") || 1500)
        running: (Quickshell.env("LENS_RIG") || "") !== ""
        onTriggered: {
            var steps = JSON.parse(Quickshell.env("LENS_RIG"));
            for (var i = 0; i < steps.length; i++) {
                var s = steps[i];
                if (s.index !== undefined)
                    win.index = s.index;
                if (s.edit)
                    win.openEditor(s.edit);
                if (s.info !== undefined)
                    win.showInfo = s.info;
                if (s.change)
                    win.change(s.change);
                if (s.adjust)
                    for (var k in s.adjust) win.setAdjust(k, s.adjust[k])
                if (s.zoom)
                    stage.zoomTo(s.zoom, undefined, undefined, false);
                if (s.overview !== undefined)
                    win.overview = s.overview;
                if (s.menu === "picture")
                    win.pictureMenu(s.x || 300, s.y || 200);
                if (s.menu === "more")
                    win.moreMenu(s.x || 600, s.y || 70);
                if (s.say)
                    win.say(s.say, s.action || "", null);
                if (s.keys)
                    win.showKeys();
                if (s.immersive !== undefined)
                    win.immersive = s.immersive;
                if (s.save !== undefined)
                    win.save(s.save === "copy");
                if (s.dump)
                    console.log("DUMP", JSON.stringify(win.current), stage.current ? stage.current.status + " " + stage.current.source + " " + stage.current.natW : "none");
            }
        }
    }

    // the render rig's hook: a picture of the window, then quit
    Timer {
        interval: Number(Quickshell.env("LENS_SHOT_MS") || 3000)
        running: (Quickshell.env("LENS_SHOT") || "") !== ""
        onTriggered: root.grabToImage(function(r) {
            console.log("LENS GRAB", r.saveToFile(Quickshell.env("LENS_SHOT")));
            if ((Quickshell.env("LENS_STAY") || "") === "")
                Qt.quit();

        })
    }

}
