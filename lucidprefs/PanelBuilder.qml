import QtQuick
import qs
import qs.lucidcc
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, big tiles,
// tiles, media, gauges) on the panel's own grid, bento style. each is the
// panel's own CcBlock with made-up readings, drawn full size and the whole
// grid scaled down to fit, so it reads as the panel does. a block is dragged
// by anything but its pieces, or by its name, to any cell and stretched by any
// edge or corner; the shelf above adds blocks and pieces and takes back what is
// dragged onto it. inside a block the pieces are dragged into order and taken
// out with their cross; a tile is dragged, or tapped, across to the other kind
// of tile. a right click offers what a block or piece can do, a picked block
// moves and stretches with the keys, and every change can be undone
Item {
    id: builder

    // the panel's measures, as System.qml takes them: a column a tile wide, a
    // row a thin strip, and the gap between
    readonly property real unit: Theme.dp(52)
    readonly property real rowUnit: Theme.dp(20)
    readonly property real gridGap: Theme.dp(12)
    readonly property int boardCols: Prefs.systemGridCols
    // how much the grid is drawn down to fit the page
    readonly property real k: Math.max(0.3, Math.min(1, builder.width / builder.span(builder.boardCols)))
    readonly property real stepX: builder.unit + builder.gridGap
    readonly property real stepY: builder.rowUnit + builder.gridGap
    // across, where each block sits does not hang on what it holds
    readonly property var spots: Prefs.systemGridPlace(Prefs.systemBlockKeys)
    // the rows each block's pieces need, as the panel's will
    readonly property var needs: {
        const out = {};
        for (let i = 0; i < boardRepeater.count; i++) {
            const it = boardRepeater.itemAt(i);
            if (it)
                out[it.blockKey] = it.needRows;

        }
        return out;
    }
    readonly property var place: Prefs.systemGridPlace(Prefs.systemBlockKeys, builder.needs)
    readonly property bool slidersStand: !!(builder.spots.sliders && !builder.spots.sliders.lie)
    // down to the lowest block, and room under it to drop one
    readonly property int boardRows: Prefs.systemBlockKeys.reduce((n, key) => {
        const r = builder.place[key];
        return r ? Math.max(n, r.y + r.h) : n;
    }, 0) + 6
    // where a block is being carried or stretched to, outlined on the grid
    property var target: null
    // the shelf's page: blocks, tiles, sliders or gauges
    property string tab: "blocks"
    // a piece being dragged off a block, or anything carried from the shelf,
    // under the pointer (in the builder's own pixels), and where it would land
    property var ghost: null
    property var carry: null
    property point ghostAt: Qt.point(0, 0)
    property var drop: null
    // something from the grid is over the shelf, to be taken out
    property bool overShelf: false
    // a block being stretched by an edge or corner, for its size beside it
    property bool sizing: false
    // the block a click or Tab picked, which the arrows move and stretch
    property string selected: ""
    // a right click's menu: the block, the piece (or ""), where, and what it offers
    property var menu: null
    // what the shelf's tiles page is narrowed to
    property string query: ""
    // a line after something came off the panel, with undo beside it
    property string notice: ""
    // the layout before each change, to step back through; what undo stepped
    // back from, to step forward again; and the layout as it was last seen
    property var undoStack: []
    property var redoStack: []
    property var last: null
    // one of the user's own tiles, to be brought up where it is edited
    signal editOwnTile(string key)

    readonly property var shelfTabs: [
        { "key": "blocks", "label": "Blocks" },
        { "key": "tiles", "label": "Tiles" },
        { "key": "sliders", "label": "Sliders" },
        { "key": "gauges", "label": "Gauges" }
    ]
    // what the shelf offers on a page: every block, shown or not, and the
    // pieces not on the panel yet
    function shelfItems(tab) {
        if (tab === "blocks")
            return Prefs.systemBlockCatalog.map((b) => {
            return {
                "kind": "block",
                "key": b.key,
                "name": b.name,
                "icon": b.icon,
                "on": Prefs.systemBlockKeys.indexOf(b.key) !== -1
            };
        });

        const block = tab === "tiles" ? "tiles" : tab;
        const kind = tab === "tiles" ? "tile" : (tab === "sliders" ? "slider" : "gauge");
        const q = tab === "tiles" ? builder.query.trim().toLowerCase() : "";
        return builder.spareOf(block).filter((k) => {
            const e = builder.entryOf(block, k);
            return q === "" || k.indexOf(q) !== -1 || (!!e && e.name.toLowerCase().indexOf(q) !== -1);
        }).map((k) => {
            const e = builder.entryOf(block, k) || {
                "icon": "",
                "name": k
            };
            return {
                "kind": kind,
                "key": k,
                "name": e.name,
                "icon": e.icon,
                "on": false
            };
        });
    }

    // what is left to add, whatever the search narrows the page to
    function shelfCount(tab) {
        if (tab !== "blocks")
            return builder.spareOf(tab).length;

        return builder.shelfItems(tab).filter((i) => {
            return !i.on;
        }).length;
    }

    function shelfHas(p) {
        return p.x >= shelf.x && p.x < shelf.x + shelf.width && p.y >= shelf.y && p.y < shelf.y + shelf.height;
    }

    // which block takes a piece of a kind
    function accepts(block, kind) {
        return kind === "tile" ? builder.isTiles(block) : (kind === "slider" ? block === "sliders" : (kind === "gauge" && block === "gauges"));
    }

    function homeOf(kind) {
        return kind === "tile" ? "tiles" : (kind === "slider" ? "sliders" : "gauges");
    }

    // a piece into a block, at a place in it or at its end, the block shown if it was not
    function insertPiece(block, key, index) {
        if (builder.isTiles(block)) {
            builder.moveTile(key, block, index);
            return ;
        }
        const l = builder.keysOf(block).filter((k) => {
            return k !== key;
        });
        l.splice(index < 0 || index > l.length ? l.length : index, 0, key);
        builder.setKeys(block, l);
        if (Prefs.systemBlockKeys.indexOf(block) === -1)
            builder.setBlockShown(block, true);

    }

    // a click on the shelf: a block goes on the panel, a piece to the end of its block
    function addItem(item) {
        if (item.kind === "block") {
            if (!item.on)
                builder.setBlockShown(item.key, true);

            return ;
        }
        builder.insertPiece(builder.homeOf(item.kind), item.key, -1);
    }

    // carrying from the shelf: a block snaps to a cell, a piece to a block that takes it
    function carryStart(item, p) {
        builder.carry = item;
        builder.ghostAt = p;
    }

    function carryTo(p) {
        builder.ghostAt = p;
        const bp = board.mapFromItem(builder, p.x, p.y);
        const inside = bp.x >= 0 && bp.y >= 0 && bp.x < board.width && bp.y < board.height;
        if (builder.carry.kind === "block") {
            const w = Prefs.systemGridFit(builder.carry.key, Prefs.systemGridSaved[builder.carry.key] || {}).w;
            builder.target = inside ? {
                "x": Math.max(0, Math.min(builder.boardCols - w, Math.round((bp.x - builder.span(w) / 2) / builder.stepX))),
                "y": Math.max(0, Math.round((bp.y - builder.rowUnit) / builder.stepY)),
                "w": w,
                "h": 3
            } : null;
            return ;
        }
        const c = inside ? builder.cardAt(bp) : null;
        if (c && builder.accepts(c.blockKey, builder.carry.kind)) {
            const q = c.mapFromItem(board, bp.x, bp.y);
            builder.drop = {
                "card": c,
                "index": c.pieceIndexAt(q.x, q.y)
            };
        } else {
            builder.drop = null;
        }
    }

    function carryEnd() {
        const c = builder.carry, t = builder.target, d = builder.drop;
        builder.carry = null;
        builder.target = null;
        builder.drop = null;
        if (!c)
            return ;

        if (c.kind === "block" && t) {
            if (!c.on)
                builder.setBlockShown(c.key, true);

            Prefs.systemGridSet(c.key, {
                "x": t.x,
                "y": t.y
            }, builder.needs);
        } else if (c.kind !== "block" && d) {
            builder.insertPiece(d.card.blockKey, c.key, d.index);
        }
    }

    function span(n) {
        return n * builder.unit + Math.max(0, n - 1) * builder.gridGap;
    }

    function rowSpan(n) {
        return n * builder.rowUnit + Math.max(0, n - 1) * builder.gridGap;
    }

    // a spot on the grid, in the grid's own pixels
    function boxOf(r) {
        return Qt.rect(r.x * builder.stepX, r.y * builder.stepY, builder.span(r.w), builder.rowSpan(r.h));
    }

    function freeFor(key, r) {
        return !Prefs.systemBlockKeys.some((k) => {
            return k !== key && builder.place[k] && Prefs.systemGridOverlap(r, builder.place[k]);
        });
    }

    // the card under a point on the grid
    function cardAt(p) {
        for (let i = 0; i < boardRepeater.count; i++) {
            const it = boardRepeater.itemAt(i);
            if (it && p.x >= it.x && p.x < it.x + it.width && p.y >= it.y && p.y < it.y + it.height)
                return it;

        }
        return null;
    }

    function isTiles(block) {
        return block === "bigtiles" || block === "tiles";
    }

    function catalogueOf(block) {
        if (block === "sliders")
            return Prefs.systemSliderCatalog;

        if (block === "gauges")
            return Prefs.systemInfoCatalog;

        return builder.isTiles(block) ? Prefs.systemTileCatalog : [];
    }

    function keysOf(block) {
        switch (block) {
        case "sliders":
            return Prefs.systemSliderKeys;
        case "bigtiles":
            return Prefs.systemBigTileKeys;
        case "tiles":
            return Prefs.systemSmallTileKeys;
        case "media":
            return ["media"];
        }
        return Prefs.systemInfoKeys;
    }

    // what can still go in a block: either tile block offers every tile in neither
    function spareOf(block) {
        const keys = builder.isTiles(block) ? Prefs.systemTileKeys : builder.keysOf(block);
        return builder.catalogueOf(block).map((e) => {
            return e.key;
        }).filter((k) => {
            return keys.indexOf(k) === -1;
        });
    }

    function setKeys(block, keys) {
        if (block === "sliders")
            Prefs.systemSliders = keys.join(",");
        else if (block === "bigtiles")
            Prefs.setSystemTileBlocks(keys, Prefs.systemSmallTileKeys);
        else if (block === "tiles")
            Prefs.setSystemTileBlocks(Prefs.systemBigTileKeys, keys);
        else if (block === "gauges")
            Prefs.systemInfo = keys.join(",");
    }

    // a tile into the other tile block, at a place in it or at its end
    function moveTile(key, to, index) {
        const big = Prefs.systemBigTileKeys.filter((k) => {
            return k !== key;
        });
        const small = Prefs.systemSmallTileKeys.filter((k) => {
            return k !== key;
        });
        const list = to === "bigtiles" ? big : small;
        list.splice(index < 0 || index > list.length ? list.length : index, 0, key);
        Prefs.setSystemTileBlocks(big, small);
        if (Prefs.systemBlockKeys.indexOf(to) === -1)
            builder.setBlockShown(to, true);

    }

    function entryOf(block, key) {
        return builder.catalogueOf(block).find((e) => {
            return e.key === key;
        }) || null;
    }

    // the sliders stood up or laid down, taking the rows they need turned and
    // not the ones they had. when that is fewer, what sat under them comes up
    function turnSliders() {
        const was = builder.place.sliders;
        Prefs.systemGridSet("sliders", {
            "lie": builder.slidersStand,
            "h": 0
        }, Object.assign({}, builder.needs, {
            "sliders": 1
        }));
        Qt.callLater(() => {
            const now = builder.place.sliders;
            const freed = was.y + was.h - (now.y + now.h);
            if (freed <= 0)
                return ;

            const next = Object.assign({}, Prefs.systemGridSaved);
            for (const key of Prefs.systemBlockKeys) {
                const r = builder.place[key];
                next[key] = Object.assign({}, r, {
                    "y": key !== "sliders" && r.y >= was.y + was.h ? r.y - freed : r.y,
                    "h": Prefs.systemGridOwnH(key)
                });
            }
            Prefs.systemGrid = JSON.stringify(next);
        });
    }

    function setBlockShown(key, on) {
        const l = Prefs.systemBlockKeys.filter((k) => {
            return k !== key;
        });
        if (on)
            l.push(key);

        Prefs.systemBlocks = l.join(",");
    }

    function blockName(key) {
        return (Prefs.systemBlockCatalog.find((b) => {
            return b.key === key;
        }) || {
            "name": key
        }).name;
    }

    // taking things off says so, with undo a click away
    function tell(text) {
        builder.notice = text;
        noticeTimer.restart();
    }

    function hideBlock(key) {
        if (Prefs.systemBlockKeys.length < 2)
            return ;

        builder.setBlockShown(key, false);
        if (builder.selected === key)
            builder.selected = "";

        builder.tell(builder.blockName(key) + " is off the panel");
    }

    function removePiece(block, key) {
        const e = builder.entryOf(block, key);
        builder.setKeys(block, builder.keysOf(block).filter((k) => {
            return k !== key;
        }));
        builder.tell((e ? e.name : key) + " is off the panel");
    }

    // a change is kept once the prefs settle, so a drag, or a turn that
    // writes twice, is one step back
    function record() {
        settle.stop();
        const now = Prefs.systemLayoutNow();
        if (builder.last && !Prefs.systemLayoutSame(now, builder.last)) {
            builder.undoStack = builder.undoStack.slice(-29).concat([builder.last]);
            builder.redoStack = [];
        }
        builder.last = now;
    }

    function undo() {
        builder.record();
        if (builder.undoStack.length === 0)
            return ;

        const to = builder.undoStack[builder.undoStack.length - 1];
        builder.undoStack = builder.undoStack.slice(0, -1);
        builder.redoStack = builder.redoStack.concat([builder.last]);
        builder.last = to;
        builder.notice = "";
        Prefs.systemLayoutApply(to);
    }

    function redo() {
        builder.record();
        if (builder.redoStack.length === 0)
            return ;

        const to = builder.redoStack[builder.redoStack.length - 1];
        builder.redoStack = builder.redoStack.slice(0, -1);
        builder.undoStack = builder.undoStack.concat([builder.last]);
        builder.last = to;
        builder.notice = "";
        Prefs.systemLayoutApply(to);
    }

    // the blocks top to bottom, then left to right, as they read
    function readingOrder() {
        return Prefs.systemBlockKeys.filter((k) => {
            return !!builder.place[k];
        }).sort((a, b) => {
            return builder.place[a].y - builder.place[b].y || builder.place[a].x - builder.place[b].x;
        });
    }

    // every block as high as it can go, and the lot against the left edge;
    // null when they are already
    readonly property var tidied: {
        const keys = builder.readingOrder();
        const left = keys.reduce((n, k) => {
            return Math.min(n, builder.place[k].x);
        }, builder.boardCols);
        const done = [];
        let moved = false;
        for (const k of keys) {
            const r = Object.assign({}, builder.place[k]);
            r.x -= left;
            const clear = (y) => {
                return !done.some((t) => {
                    return Prefs.systemGridOverlap(Object.assign({}, r, {
                        "y": y
                    }), t);
                });
            };
            while (r.y > 0 && clear(r.y - 1))
                r.y--;
            moved = moved || r.x !== builder.place[k].x || r.y !== builder.place[k].y;
            done.push(Object.assign({
                "key": k
            }, r));
        }
        return moved ? done : null;
    }

    function tidy() {
        if (!builder.tidied)
            return ;

        const next = Object.assign({}, Prefs.systemGridSaved);
        for (const r of builder.tidied)
            next[r.key] = {
            "x": r.x,
            "y": r.y,
            "w": r.w,
            "h": Prefs.systemGridOwnH(r.key),
            "lie": r.lie
        };
        Prefs.systemGrid = JSON.stringify(next);
    }

    function cardOf(key) {
        for (let i = 0; i < boardRepeater.count; i++) {
            const it = boardRepeater.itemAt(i);
            if (it && it.blockKey === key)
                return it;

        }
        return null;
    }

    // the picked block a column or a row over; one it lands on trades places
    function nudge(dx, dy) {
        const c = builder.place[builder.selected];
        if (!c)
            return ;

        const x = Math.max(0, Math.min(builder.boardCols - c.w, c.x + dx));
        const y = Math.max(0, c.y + dy);
        if (x !== c.x || y !== c.y)
            Prefs.systemGridSet(builder.selected, {
            "x": x,
            "y": y
        }, builder.needs);

    }

    // the picked block a step wider or narrower (in widths it can take), or a
    // row taller or shorter, where there is room
    function stretch(dw, dh) {
        const key = builder.selected;
        const c = builder.place[key];
        const card = builder.cardOf(key);
        if (!c || !card)
            return ;

        const step = key === "bigtiles" ? 3 : (key === "sliders" && !c.lie ? Prefs.systemGridMinW(key, false) : 1);
        const w = dw === 0 ? c.w : Prefs.systemGridSnapW(key, c.lie, c.w + dw * step);
        const h = Math.max(card.needRows, c.h + dh);
        const want = {
            "x": c.x,
            "y": c.y,
            "w": w,
            "h": h
        };
        if ((w === c.w && h === c.h) || c.x + w > builder.boardCols || !builder.freeFor(key, want))
            return ;

        const spot = {
            "w": w
        };
        if (dh !== 0)
            spot.h = h;

        Prefs.systemGridSet(key, spot, builder.needs);
    }

    // back to six columns, and only as tall as what it holds
    function resetSize(key) {
        const c = builder.place[key];
        if (!c)
            return ;

        const need = {};
        need[key] = 1;
        Prefs.systemGridSet(key, {
            "w": Prefs.systemGridSnapW(key, c.lie, 6),
            "h": 1
        }, Object.assign({}, builder.needs, need));
    }

    // what a right click on a block offers, and on a piece of it first what the piece can do
    function openMenu(card, piece, p) {
        const block = card.blockKey;
        const items = [];
        const key = piece >= 0 ? card.order[piece] : "";
        if (key !== "") {
            if (block === "tiles")
                items.push({
                "act": "big",
                "icon": "dashboard",
                "label": "Make it big"
            });
            else if (block === "bigtiles")
                items.push({
                "act": "small",
                "icon": "apps",
                "label": "Make it small"
            });
            if (Prefs.systemOwnTile(key))
                items.push({
                "act": "edit",
                "icon": "edit",
                "label": "Edit this tile"
            });

            if (builder.isTiles(block) || card.order.length > 1)
                items.push({
                "act": "off",
                "icon": "close",
                "label": "Take it off"
            });

            if (items.length > 0)
                items.push({
                "act": ""
            });

        }
        if (block === "sliders")
            items.push({
            "act": "turn",
            "icon": builder.slidersStand ? "width" : "height",
            "label": builder.slidersStand ? "Lay them down" : "Stand them up"
        });

        items.push({
            "act": "size",
            "icon": "restart_alt",
            "label": "Reset its size"
        });
        if (Prefs.systemBlockKeys.length > 1)
            items.push({
            "act": "hide",
            "icon": "visibility_off",
            "label": "Hide " + builder.blockName(block)
        });

        // and the looks it can take, the one it has ticked
        const looks = Prefs.systemStyleCatalog[block] || [];
        if (looks.length > 1) {
            items.push({
                "act": "",
                "label": "Look"
            });
            for (const l of looks)
                items.push({
                "act": "look:" + l.key,
                "icon": Prefs.systemBlockStyle(block) === l.key ? "check" : "",
                "label": l.name
            });
        }
        builder.selected = block;
        builder.menu = {
            "block": block,
            "piece": key,
            "x": p.x,
            "y": p.y,
            "items": items
        };
    }

    function menuAct(act) {
        const m = builder.menu;
        builder.menu = null;
        if (!m)
            return ;

        if (act === "big")
            builder.moveTile(m.piece, "bigtiles", -1);
        else if (act === "small")
            builder.moveTile(m.piece, "tiles", -1);
        else if (act === "edit")
            builder.editOwnTile(m.piece);
        else if (act === "off")
            builder.removePiece(m.block, m.piece);
        else if (act === "turn")
            builder.turnSliders();
        else if (act === "size")
            builder.resetSize(m.block);
        else if (act === "hide")
            builder.hideBlock(m.block);
        else if (act.indexOf("look:") === 0)
            Prefs.setSystemBlockStyle(m.block, act.substring(5));
    }

    width: parent ? parent.width : 0
    implicitHeight: boardWrap.y + boardWrap.height
    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (!builder.activeFocus) {
            builder.selected = "";
            builder.menu = null;
        }
    }
    // the three blocks there were once are written out as the five, and the
    // layout from here on is what undo goes back to
    Component.onCompleted: {
        Prefs.systemMigrate();
        builder.last = Prefs.systemLayoutNow();
    }
    // ctrl+z and ctrl+shift+z (or ctrl+y) step back and forth; tab picks the
    // blocks in turn, the arrows move the one picked, with shift they
    // stretch it, and delete hides it
    Keys.onPressed: (e) => {
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        e.accepted = true;
        if (ctrl && e.key === Qt.Key_Z) {
            if (shift)
                builder.redo();
            else
                builder.undo();
            return ;
        }
        if (ctrl && e.key === Qt.Key_Y) {
            builder.redo();
            return ;
        }
        if (e.key === Qt.Key_Escape && (builder.menu || builder.selected !== "")) {
            if (builder.menu)
                builder.menu = null;
            else
                builder.selected = "";
            return ;
        }
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) {
            e.accepted = false;
            return ;
        }
        if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
            const order = builder.readingOrder();
            const i = order.indexOf(builder.selected);
            const next = e.key === Qt.Key_Tab ? (i < 0 ? 0 : i + 1) : (i < 0 ? order.length - 1 : i - 1);
            builder.menu = null;
            builder.selected = next >= 0 && next < order.length ? order[next] : "";
            // past the last one, focus moves on as tab always does
            e.accepted = builder.selected !== "";
            return ;
        }
        if (builder.selected === "") {
            e.accepted = false;
            return ;
        }
        const dx = e.key === Qt.Key_Left ? -1 : (e.key === Qt.Key_Right ? 1 : 0);
        const dy = e.key === Qt.Key_Up ? -1 : (e.key === Qt.Key_Down ? 1 : 0);
        if (dx !== 0 || dy !== 0) {
            if (shift)
                builder.stretch(dx, dy);
            else
                builder.nudge(dx, dy);
        } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
            builder.hideBlock(builder.selected);
        } else {
            e.accepted = false;
        }
    }

    Timer {
        id: settle

        interval: 250
        onTriggered: builder.record()
    }

    Timer {
        id: noticeTimer

        interval: 6000
        onTriggered: builder.notice = ""
    }

    // every change to the layout, from here or anywhere, is a step undo can take back
    Connections {
        function onSystemBlocksChanged() {
            settle.restart();
        }

        function onSystemGridChanged() {
            settle.restart();
        }

        function onSystemTilesChanged() {
            settle.restart();
        }

        function onSystemTilesRadiosChanged() {
            settle.restart();
        }

        function onSystemBigTilesChanged() {
            settle.restart();
        }

        function onSystemSlidersChanged() {
            settle.restart();
        }

        function onSystemInfoChanged() {
            settle.restart();
        }

        target: Prefs
    }

    // made-up readings, so the blocks show as they would in the panel
    QtObject {
        id: sample

        readonly property bool expanded: false
        readonly property var tilePages: ["wifi", "bluetooth", "profile", "nightlight"]
        readonly property string mediaTitle: "Song title"
        readonly property string mediaArtist: "Artist"
        readonly property string mediaArt: ""
        readonly property real mediaProgress: 0.4
        readonly property bool mediaPlaying: false
        readonly property real mediaPosition: 74
        readonly property real mediaLength: 185

        function tileEntry(k) {
            return builder.entryOf("tiles", k) || {
                "icon": "",
                "name": k
            };
        }

        function tileIcon(k) {
            return sample.tileEntry(k).icon;
        }

        function tileLabel(k) {
            return sample.tileEntry(k).name;
        }

        function bigName(k) {
            return sample.tileEntry(k).name;
        }

        function bigSub(k) {
            return k === "wifi" ? "Connected" : (sample.tileChecked(k) ? "On" : "Off");
        }

        // the radios on, and every third tile of either kind, so a look shows both states
        function tileChecked(k) {
            return k === "wifi" || k === "bluetooth" || Prefs.systemSmallTileKeys.indexOf(k) % 3 === 0 || Prefs.systemBigTileKeys.indexOf(k) % 3 === 0;
        }

        function tileAct(k) {
        }

        function showView(v) {
        }

        function sliderIcon(k) {
            const e = builder.entryOf("sliders", k);
            return e ? e.icon : "";
        }

        function sliderValue(k) {
            return k === "brightness" ? 60 : (k === "volume" ? 45 : 70);
        }

        function sliderMuted(k) {
            return false;
        }

        function sliderMove(k, v) {
        }

        function sliderIconClick(k) {
        }

        function mediaPrev() {
        }

        function mediaToggle() {
        }

        function mediaNext() {
        }

        function mediaOpen() {
        }

        function mediaSeek(s) {
        }

        function gauge(k) {
            const e = builder.entryOf("gauges", k);
            const v = {
                "cpu": [0.28, "62 °C"],
                "ram": [0.62, "9.4 GB"],
                "disk": [0.38, "297 GB free"],
                "battery": [0.8, "Full"]
            }[k] || [0.5, ""];
            // a made-up minute for what keeps its last readings
            const wave = (base, a, f) => {
                const out = [];
                for (let i = 0; i < 16; i++)
                    out.push(Math.max(0, Math.min(1, base + a * Math.sin(i / f) + a * 0.4 * Math.sin(i / 1.3))));
                return out;
            };
            return {
                "value": v[0],
                "center": Math.round(v[0] * 100) + "",
                "label": e ? e.name : k,
                "detail": v[1],
                "tone": Theme.accent,
                "icon": "",
                "history": k === "cpu" ? wave(0.28, 0.14, 2.1) : (k === "ram" ? wave(0.6, 0.03, 3.4) : [])
            };
        }

        function gaugeClick(k) {
        }

    }

    // the shelf: every block and every piece not on the panel yet, drawn as
    // the panel draws them. a click adds one, a drag puts it where it is let
    // go; a piece or a block dragged back here comes off the panel
    Rectangle {
        id: shelf

        width: parent.width
        height: shelfCol.implicitHeight + Theme.dp(32)
        radius: Theme.radiusLg
        color: builder.overShelf ? Theme.alpha(Theme.error, 0.12) : Theme.bgSunken
        border.width: builder.overShelf ? Theme.dp(2) : 0
        border.color: Theme.error

        Column {
            id: shelfCol

            x: Theme.dp(16)
            y: Theme.dp(16)
            width: parent.width - Theme.dp(32)
            spacing: Theme.dp(12)

            Column {
                width: parent.width
                spacing: Theme.dp(2)

                LText {
                    role: "titleSmall"
                    weight: 600
                    text: builder.overShelf ? "Let go to take it off the panel" : "Add to the panel"
                    color: builder.overShelf ? Theme.error : Theme.text
                }

                LText {
                    width: parent.width
                    role: "bodySmall"
                    color: Theme.subtext
                    wrapMode: Text.WordWrap
                    text: "Click one to add it, or drag it onto the grid: a tile, a slider or a gauge into its block, a whole block onto any spot. To take something off, drag it back here."
                }

            }

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

                Repeater {
                    model: builder.shelfTabs

                    Chip {
                        required property var modelData
                        readonly property int count: builder.shelfCount(modelData.key)

                        kind: "filter"
                        text: modelData.label + (count > 0 ? "  " + count : "")
                        selected: builder.tab === modelData.key
                        onClicked: {
                            builder.tab = modelData.key;
                            builder.query = "";
                            shelfSearch.clear();
                        }
                    }

                }

            }

            // the tiles are many, so their page can be searched
            M3TextField {
                id: shelfSearch

                visible: builder.tab === "tiles"
                width: Math.min(parent.width, Theme.dp(320))
                placeholder: "Search the tiles"
                commitOnBlur: false
                onEdited: (v) => {
                    return builder.query = v;
                }
                onCancelled: {
                    shelfSearch.clear();
                    builder.query = "";
                }
            }

            Flow {
                id: shelfFlow

                readonly property var items: builder.shelfItems(builder.tab)

                width: parent.width
                spacing: Theme.dp(8)

                Repeater {
                    model: shelfFlow.items

                    ShelfItem {
                        required property var modelData

                        item: modelData
                    }

                }

            }

            LText {
                visible: shelfFlow.items.length === 0
                role: "bodySmall"
                color: Theme.subtextDim
                text: builder.tab === "tiles" && builder.query.trim() !== "" ? "No tile left to add goes by “" + builder.query.trim() + "”." : "All of them are on the panel already."
            }

        }

    }

    // undo and redo, tidying up, and a word after something came off
    Item {
        id: toolbar

        y: shelf.height + Theme.dp(12)
        width: parent.width
        height: Theme.dp(40)

        Row {
            id: tools

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(4)

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(36)
                iconPath: "undo"
                enabled: builder.undoStack.length > 0 || settle.running
                onClicked: builder.undo()
            }

            M3IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(36)
                iconPath: "redo"
                enabled: builder.redoStack.length > 0
                onClicked: builder.redo()
            }

            Item {
                width: Theme.dp(4)
                height: 1
            }

            // every block as high as it goes, the lot against the left edge
            M3Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "tonal"
                text: "Tidy up"
                iconPath: "vertical_align_top"
                enabled: builder.tidied !== null
                onClicked: builder.tidy()
            }

        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(4)
            visible: builder.notice !== ""

            LText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, toolbar.width - tools.width - Theme.dp(110))
                role: "bodyMedium"
                color: Theme.subtext
                elide: Text.ElideRight
                text: builder.notice
            }

            M3Button {
                anchors.verticalCenter: parent.verticalCenter
                variant: "text"
                text: "Undo"
                onClicked: builder.undo()
            }

        }

    }

    // how each block is drawn. with none picked, the blocks and the look each
    // has, to pick one; with one picked, each of its looks drawn as the panel
    // would draw it, a click away
    Rectangle {
        id: looksBar

        readonly property string block: builder.selected !== "" && (Prefs.systemStyleCatalog[builder.selected] || []).length > 1 ? builder.selected : ""

        y: toolbar.y + toolbar.height + Theme.dp(8)
        width: parent.width
        height: looksCol.implicitHeight + Theme.dp(28)
        radius: Theme.radiusLg
        color: Theme.bgSunken

        Column {
            id: looksCol

            x: Theme.dp(16)
            y: Theme.dp(14)
            width: parent.width - Theme.dp(32)
            spacing: Theme.dp(10)

            // the same height whichever it shows, so the grid under it never moves
            Item {
                width: parent.width
                height: Theme.dp(40)

                Column {
                    anchors.left: parent.left
                    anchors.right: allBlocks.left
                    anchors.rightMargin: Theme.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(2)

                    LText {
                        width: parent.width
                        role: "titleSmall"
                        weight: 600
                        text: looksBar.block === "" ? "Looks" : builder.blockName(looksBar.block) + ": its look"
                        elide: Text.ElideRight
                    }

                    LText {
                        width: parent.width
                        role: "bodySmall"
                        color: Theme.subtext
                        text: looksBar.block === "" ? "Every block can be drawn more than one way. Pick one here, or click it on the grid, for its looks." : "Click one to use it; Ctrl+Z goes back."
                        elide: Text.ElideRight
                    }

                }

                M3Button {
                    id: allBlocks

                    visible: looksBar.block !== ""
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "text"
                    text: "All blocks"
                    onClicked: builder.selected = ""
                }

            }

            // one row, sliding sideways where it is wider than the page: the
            // blocks in the look each has, or the picked block's looks
            Flickable {
                width: parent.width
                height: Theme.dp(150)
                contentWidth: looksRow.width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: looksRow

                    spacing: Theme.dp(8)

                    Repeater {
                        model: looksBar.block === "" ? builder.readingOrder() : []

                        LookTile {
                            required property string modelData

                            block: modelData
                            look: (Prefs.systemStyleCatalog[modelData] || []).find((l) => {
                                return l.key === Prefs.systemBlockStyle(modelData);
                            }) || null
                            picker: true
                        }

                    }

                    Repeater {
                        model: looksBar.block !== "" ? Prefs.systemStyleCatalog[looksBar.block] : []

                        LookTile {
                            required property var modelData

                            block: looksBar.block
                            look: modelData
                        }

                    }

                }

            }

        }

    }

    // the grid, full size and scaled down as one
    Item {
        id: boardWrap

        y: looksBar.y + looksBar.height + Theme.dp(12)
        width: Math.round(board.width * builder.k)
        height: Math.round(board.height * builder.k)
        x: Math.max(0, Math.round((builder.width - width) / 2))

        Item {
            id: board

            width: builder.span(builder.boardCols)
            height: builder.rowSpan(builder.boardRows)
            scale: builder.k
            transformOrigin: Item.TopLeft

            // a press on no block lets go of the one picked, and takes the keys
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: {
                    builder.forceActiveFocus();
                    builder.selected = "";
                    builder.menu = null;
                }
            }

            // a faint stripe for each column, plainer while something is carried or stretched
            Repeater {
                model: builder.boardCols

                Rectangle {
                    required property int index

                    x: index * builder.stepX
                    width: builder.unit
                    height: board.height
                    radius: Theme.dp(8)
                    color: Theme.alpha(Theme.text, builder.target ? 0.07 : 0.035)
                }

            }

            // where the block being carried or stretched would go
            Rectangle {
                id: targetBox

                readonly property rect box: builder.target ? builder.boxOf(builder.target) : Qt.rect(0, 0, 0, 0)

                visible: builder.target !== null
                x: box.x
                y: box.y
                width: box.width
                height: box.height
                radius: Theme.radiusMd
                color: Theme.alpha(Theme.accent, 0.12)
                border.width: Theme.dp(2)
                border.color: Theme.accent
            }

            // and, while it is stretched, how big, over the block itself;
            // drawn at the size it reads, whatever the grid is scaled to
            Rectangle {
                visible: builder.sizing && builder.target !== null
                z: 7
                x: targetBox.x + (targetBox.width - width) / 2
                y: targetBox.y + (targetBox.height - height) / 2
                scale: 1 / builder.k
                width: sizeText.implicitWidth + Theme.dp(20)
                height: Theme.dp(28)
                radius: height / 2
                color: Theme.accent

                Text {
                    id: sizeText

                    anchors.centerIn: parent
                    text: builder.target ? builder.target.w + (builder.target.w === 1 ? " column" : " columns") + " × " + builder.target.h + (builder.target.h === 1 ? " row" : " rows") : ""
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.DemiBold
                }

            }

            Repeater {
                id: boardRepeater

                model: Prefs.systemBlockKeys

                BlockCard {
                    required property string modelData

                    blockKey: modelData
                }

            }

        }

    }

    // the piece or block being carried, over everything: red over the shelf
    Rectangle {
        id: ghostItem

        readonly property var what: builder.carry ? {
            "icon": builder.carry.icon,
            "name": builder.carry.name
        } : (builder.ghost ? builder.entryOf(builder.ghost.block, builder.ghost.key) : null)

        visible: builder.ghost !== null || builder.carry !== null
        z: 20
        width: builder.ghost ? Math.max(Theme.dp(40), builder.ghost.w * builder.k) : Theme.dp(150)
        height: builder.ghost ? Math.max(Theme.dp(40), builder.ghost.h * builder.k) : Theme.dp(44)
        x: builder.ghostAt.x - width / 2
        y: builder.ghostAt.y - height / 2
        radius: Math.min(Theme.radiusMd, height / 2)
        color: Theme.withBlur(Theme.surfaceHighest)
        border.width: Theme.dp(2)
        border.color: builder.overShelf ? Theme.error : Theme.accent

        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(6)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: ghostItem.what ? ghostItem.what.icon : ""
                size: Theme.dp(20)
                color: Theme.text
            }

            Text {
                visible: ghostItem.width > Theme.dp(90)
                anchors.verticalCenter: parent.verticalCenter
                text: ghostItem.what ? ghostItem.what.name : ""
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
            }

        }

    }

    // a press anywhere off the menu closes it
    MouseArea {
        visible: builder.menu !== null
        anchors.fill: parent
        z: 29
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: builder.menu = null
    }

    // a right click's menu, kept inside the builder
    Rectangle {
        id: menuBox

        visible: builder.menu !== null
        z: 30
        width: Theme.dp(220)
        height: menuCol.implicitHeight + Theme.dp(12)
        x: builder.menu ? Math.max(0, Math.min(builder.width - width, builder.menu.x)) : 0
        y: builder.menu ? Math.max(0, Math.min(builder.height - height, builder.menu.y)) : 0
        radius: Theme.radiusMd
        color: Theme.withBlur(Theme.surfaceHighest)
        border.width: 1
        border.color: Theme.outline

        Column {
            id: menuCol

            x: Theme.dp(6)
            y: Theme.dp(6)
            width: parent.width - Theme.dp(12)

            Repeater {
                model: builder.menu ? builder.menu.items : []

                Item {
                    id: menuRow

                    required property var modelData

                    readonly property bool caption: menuRow.modelData.act === "" && !!menuRow.modelData.label

                    width: menuCol.width
                    height: menuRow.modelData.act !== "" ? Theme.dp(38) : (menuRow.caption ? Theme.dp(34) : Theme.dp(9))

                    // a line between what the piece can do and what the block can,
                    // and over the looks, their heading
                    Rectangle {
                        visible: menuRow.modelData.act === ""
                        y: menuRow.caption ? Theme.dp(4) : (parent.height - height) / 2
                        width: parent.width
                        height: 1
                        color: Theme.outline
                    }

                    LText {
                        visible: menuRow.caption
                        x: Theme.dp(10)
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.dp(4)
                        role: "labelMedium"
                        color: Theme.subtext
                        text: menuRow.modelData.label || ""
                    }

                    Rectangle {
                        visible: menuRow.modelData.act !== ""
                        anchors.fill: parent
                        radius: Theme.radiusSm
                        color: menuArea.containsMouse ? Theme.alpha(Theme.text, 0.08) : "transparent"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Theme.dp(10)
                            spacing: Theme.dp(12)

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: menuRow.modelData.icon || ""
                                size: Theme.dp(18)
                                color: Theme.subtext
                            }

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "labelLarge"
                                text: menuRow.modelData.label || ""
                            }

                        }

                        MouseArea {
                            id: menuArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: builder.menuAct(menuRow.modelData.act)
                        }

                    }

                }

            }

        }

    }

    // a block on the grid, the panel's own, filling its cells. dragged by
    // anything but its pieces it moves; its edges and corners stretch it; its
    // pieces are dragged into order, a tile across to the other tile block
    component BlockCard: Item {
        id: card

        property string blockKey: ""
        // the pieces in the order shown, while one is dragged too
        property var liveOrder: null
        readonly property var order: card.liveOrder || builder.keysOf(card.blockKey)
        readonly property var spot: builder.spots[card.blockKey] || null
        readonly property var cell: builder.place[card.blockKey] || card.spot
        readonly property rect box: card.cell ? builder.boxOf(card.cell) : Qt.rect(0, 0, 0, 0)
        readonly property bool editable: card.blockKey !== "media"
        readonly property int needRows: Math.max(1, Math.ceil((view.implicitHeight + builder.gridGap) / builder.stepY))
        readonly property bool busy: area.mode === 1 || tagArea.pressed || card.sizing
        // picked by a click or tab, for the keys
        readonly property bool picked: builder.selected === card.blockKey && builder.activeFocus
        property bool sizing: false
        // the piece the pointer is on, and the one showing its cross
        readonly property int hovered: hover.hovered && builder.ghost === null && card.editable ? view.pieceAt(hover.point.position.x, hover.point.position.y) : -1
        property int crossAt: -1
        // how far the pointer has carried this block, and where it took hold
        property real dragDX: 0
        property real dragDY: 0
        property point grab

        // carrying the block: the card follows the pointer, its outline snaps to a cell
        function moveFrom(p) {
            card.grab = Qt.point(p.x - card.x, p.y - card.y);
        }

        function moveTo(p) {
            const left = p.x - card.grab.x, top = p.y - card.grab.y;
            card.dragDX = left - card.box.x;
            card.dragDY = top - card.box.y;
            // over the shelf it comes off the panel, if it is not the last
            builder.overShelf = Prefs.systemBlockKeys.length > 1 && builder.shelfHas(board.mapToItem(builder, p.x, p.y));
            builder.target = builder.overShelf ? null : {
                "x": Math.max(0, Math.min(builder.boardCols - card.cell.w, Math.round(left / builder.stepX))),
                "y": Math.max(0, Math.round(top / builder.stepY)),
                "w": card.cell.w,
                "h": card.cell.h
            };
        }

        // the blocks it lands on take the spot it left, or go under it
        function moveEnd() {
            card.dragDX = 0;
            card.dragDY = 0;
            const t = builder.target;
            builder.target = null;
            if (builder.overShelf) {
                builder.overShelf = false;
                builder.hideBlock(card.blockKey);
                return ;
            }
            if (t && (t.x !== card.cell.x || t.y !== card.cell.y))
                Prefs.systemGridSet(card.blockKey, {
                "x": t.x,
                "y": t.y
            }, builder.needs);

        }

        // stretching it by an edge or corner, in widths it can take, no
        // shorter than it needs and as far as the blocks around leave room
        function sizeTo(p, e) {
            const c = card.cell;
            let x = c.x, y = c.y, w = c.w, h = c.h;
            const minH = card.needRows;
            const snap = (want, room) => {
                let v = Prefs.systemGridSnapW(card.blockKey, c.lie, want);
                while (v > room && v > Prefs.systemGridMinW(card.blockKey, c.lie))
                    v = Prefs.systemGridSnapW(card.blockKey, c.lie, v - 1);
                return v;
            };
            if (e.r)
                w = snap(Math.round((p.x + builder.gridGap) / builder.stepX) - x, builder.boardCols - x);

            if (e.l) {
                const right = c.x + c.w;
                w = snap(right - Math.round(p.x / builder.stepX), right);
                x = right - w;
            }
            if (e.b)
                h = Math.max(minH, Math.round((p.y + builder.gridGap) / builder.stepY) - y);

            if (e.t) {
                const bottom = c.y + c.h;
                y = Math.max(0, Math.min(bottom - minH, Math.round(p.y / builder.stepY)));
                h = bottom - y;
            }
            const want = {
                "x": x,
                "y": y,
                "w": w,
                "h": h
            };
            if (builder.freeFor(card.blockKey, want))
                builder.target = want;
            else if (!builder.target)
                builder.target = {
                "x": c.x,
                "y": c.y,
                "w": c.w,
                "h": c.h
            };
        }

        function sizeEnd() {
            card.sizing = false;
            builder.sizing = false;
            const t = builder.target;
            builder.target = null;
            const c = card.cell;
            if (!t || (t.x === c.x && t.y === c.y && t.w === c.w && t.h === c.h))
                return ;

            // a height is kept only once it is stretched; until then it follows what the block holds
            const spot = Object.assign({}, t);
            if (t.h === c.h)
                delete spot.h;

            Prefs.systemGridSet(card.blockKey, spot, builder.needs);

        }

        // where a tile dropped here from the other block would go
        function pieceIndexAt(x, y) {
            return view.pieceAt(x, y);
        }

        onHoveredChanged: {
            if (card.hovered >= 0)
                card.crossAt = card.hovered;
            else if (!crossArea.containsMouse)
                card.crossAt = -1;
        }
        x: card.box.x + card.dragDX
        y: card.box.y + card.dragDY
        // its width from its columns alone; down, the rows decide
        width: card.spot ? builder.span(card.spot.w) : 0
        height: card.box.height
        z: card.busy ? 5 : 0

        HoverHandler {
            id: hover
        }

        // its cells, so the room it was given shows past what it holds
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.alpha(Theme.text, card.busy ? 0.08 : 0.04)
        }

        CcBlock {
            id: view

            anchors.fill: parent
            enabled: false
            kind: card.blockKey
            keys: card.order
            host: sample
            cols: card.spot ? card.spot.w : 6
            bigCols: card.spot ? Math.max(1, Math.floor(card.spot.w / 3)) : 2
            gap: builder.gridGap
            standing: card.blockKey === "sliders" && builder.slidersStand
            look: Prefs.systemBlockStyle(card.blockKey)
            cards: Prefs.systemBlockCards
        }

        // and their outline, over what it holds; thicker on the one picked
        Rectangle {
            readonly property bool lit: card.busy || hover.hovered || card.picked || (!!builder.drop && builder.drop.card === card)

            anchors.fill: parent
            z: 2
            radius: Theme.radiusMd
            color: "transparent"
            border.width: card.picked ? Theme.dp(3) : (lit ? Theme.dp(2) : Theme.dp(1))
            border.color: lit ? Theme.accent : Theme.alpha(Theme.text, 0.1)
        }

        // a press on a piece drags it, anywhere else the block; a tap on a
        // tile sends it to the other tile block
        MouseArea {
            id: area

            // 0 nothing, 1 the block, 2 a piece pressed, 3 a piece dragged
            property int mode: 0
            property point start
            property int from: -1

            anchors.fill: parent
            z: 1
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: area.mode === 1 || area.mode === 3 ? Qt.ClosedHandCursor : (card.hovered >= 0 ? Qt.PointingHandCursor : Qt.OpenHandCursor)
            onPressed: (mouse) => {
                builder.forceActiveFocus();
                builder.menu = null;
                if (mouse.button === Qt.RightButton) {
                    area.mode = 0;
                    builder.openMenu(card, card.editable ? view.pieceAt(mouse.x, mouse.y) : -1, mapToItem(builder, mouse.x, mouse.y));
                    return ;
                }
                builder.selected = card.blockKey;
                area.start = Qt.point(mouse.x, mouse.y);
                area.from = card.editable ? view.pieceAt(mouse.x, mouse.y) : -1;
                if (area.from >= 0) {
                    area.mode = 2;
                } else {
                    area.mode = 1;
                    card.moveFrom(mapToItem(board, mouse.x, mouse.y));
                }
            }
            onPositionChanged: (mouse) => {
                const p = mapToItem(board, mouse.x, mouse.y);
                if (area.mode === 1) {
                    card.moveTo(p);
                    return ;
                }
                if (area.mode === 2 && Math.abs(mouse.x - area.start.x) + Math.abs(mouse.y - area.start.y) > Theme.dp(8)) {
                    const b = view.pieceBox(area.from);
                    area.mode = 3;
                    card.liveOrder = card.order.slice();
                    builder.ghost = {
                        "block": card.blockKey,
                        "key": card.liveOrder[area.from],
                        "w": b.width,
                        "h": b.height
                    };
                }
                if (area.mode !== 3)
                    return ;

                const bp = board.mapToItem(builder, p.x, p.y);
                builder.ghostAt = bp;
                // over the shelf it comes out of the block, if it is not the last
                builder.overShelf = (builder.isTiles(card.blockKey) || card.order.length > 1) && builder.shelfHas(bp);
                const over = builder.overShelf ? null : builder.cardAt(p);
                if (builder.overShelf) {
                    builder.drop = null;
                } else if (over === card) {
                    builder.drop = null;
                    const to = view.pieceAt(mouse.x, mouse.y);
                    const at = card.liveOrder.indexOf(builder.ghost.key);
                    if (to >= 0 && to !== at) {
                        const l = card.liveOrder.slice();
                        l.splice(at, 1);
                        l.splice(to, 0, builder.ghost.key);
                        card.liveOrder = l;
                    }
                } else if (over && builder.isTiles(card.blockKey) && builder.isTiles(over.blockKey)) {
                    const q = over.mapFromItem(board, p.x, p.y);
                    builder.drop = {
                        "card": over,
                        "index": over.pieceIndexAt(q.x, q.y)
                    };
                } else {
                    builder.drop = null;
                }
            }
            onReleased: {
                if (area.mode === 1) {
                    card.moveEnd();
                } else if (area.mode === 2) {
                    // a tap: a tile goes to the end of the other tile block
                    const key = card.order[area.from];
                    if (builder.isTiles(card.blockKey))
                        builder.moveTile(key, card.blockKey === "tiles" ? "bigtiles" : "tiles", -1);

                } else if (area.mode === 3) {
                    const key = builder.ghost.key;
                    const d = builder.drop;
                    const l = card.liveOrder;
                    const out = builder.overShelf;
                    builder.ghost = null;
                    builder.drop = null;
                    builder.overShelf = false;
                    card.liveOrder = null;
                    if (out)
                        builder.removePiece(card.blockKey, key);
                    else if (d)
                        builder.moveTile(key, d.card.blockKey, d.index);
                    else
                        builder.setKeys(card.blockKey, l);
                }
                area.mode = 0;
            }
            onCanceled: {
                card.dragDX = 0;
                card.dragDY = 0;
                builder.target = null;
                builder.ghost = null;
                builder.drop = null;
                builder.overShelf = false;
                card.liveOrder = null;
                area.mode = 0;
            }
        }

        // the cross on the piece the pointer is on
        Rectangle {
            readonly property rect pb: card.crossAt >= 0 ? view.pieceBox(card.crossAt) : Qt.rect(0, 0, 0, 0)
            readonly property bool removable: builder.isTiles(card.blockKey) || card.order.length > 1

            visible: card.crossAt >= 0 && removable && area.mode === 0
            z: 3
            width: Theme.dp(22)
            height: Theme.dp(22)
            radius: width / 2
            // inside the piece's corner, so it never sits past the block's edge
            x: pb.x + pb.width - width - Theme.dp(2)
            y: pb.y + Theme.dp(2)
            color: Theme.error

            Icon {
                anchors.centerIn: parent
                name: "close"
                size: Theme.dp(14)
                color: Theme.fgError
            }

            MouseArea {
                id: crossArea

                anchors.fill: parent
                anchors.margins: -Theme.dp(3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onExited: {
                    if (card.hovered < 0)
                        card.crossAt = -1;

                }
                onClicked: {
                    const key = card.order[card.crossAt];
                    card.crossAt = -1;
                    builder.removePiece(card.blockKey, key);
                }
            }

        }

        // and a pencil on one of the user's own tiles, to go and edit it
        Rectangle {
            readonly property rect pb: card.crossAt >= 0 ? view.pieceBox(card.crossAt) : Qt.rect(0, 0, 0, 0)
            readonly property string key: card.crossAt >= 0 && builder.isTiles(card.blockKey) ? (card.order[card.crossAt] || "") : ""

            visible: key !== "" && Prefs.systemOwnTile(key) !== null && area.mode === 0
            z: 3
            width: Theme.dp(22)
            height: Theme.dp(22)
            radius: width / 2
            x: pb.x + Theme.dp(2)
            y: pb.y + Theme.dp(2)
            color: Theme.accent

            Icon {
                anchors.centerIn: parent
                name: "edit"
                size: Theme.dp(14)
                color: Theme.fgAccent
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.dp(3)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onExited: {
                    if (card.hovered < 0)
                        card.crossAt = -1;

                }
                onClicked: builder.editOwnTile(parent.key)
            }

        }

        // its name, with a handle, while the pointer is on the block or it is picked
        Rectangle {
            visible: hover.hovered || card.busy || card.picked
            x: Theme.dp(6)
            y: Theme.dp(6)
            z: 3
            width: tagRow.implicitWidth + Theme.dp(12)
            height: Theme.dp(30)
            radius: height / 2
            color: Theme.accent

            Row {
                id: tagRow

                anchors.centerIn: parent
                spacing: Theme.dp(4)

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drag_indicator"
                    size: Theme.dp(16)
                    color: Theme.fgAccent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: Theme.dp(4)
                    text: (Prefs.systemBlockCatalog.find((b) => {
                        return b.key === card.blockKey;
                    }) || {
                        "name": card.blockKey
                    }).name
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.DemiBold
                }

                // the sliders stand side by side or lie one under another
                TagButton {
                    visible: card.blockKey === "sliders"
                    icon: builder.slidersStand ? "width" : "height"
                    onClicked: builder.turnSliders()
                }

                // picks it, for its looks over the grid
                TagButton {
                    visible: (Prefs.systemStyleCatalog[card.blockKey] || []).length > 1
                    icon: "palette"
                    onClicked: {
                        builder.forceActiveFocus();
                        builder.menu = null;
                        builder.selected = card.blockKey;
                    }
                }

                // off the panel, keeping what it holds; it waits on the shelf
                TagButton {
                    visible: Prefs.systemBlockKeys.length > 1
                    icon: "visibility_off"
                    onClicked: builder.hideBlock(card.blockKey)
                }

            }

            MouseArea {
                id: tagArea

                z: -1
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                onPressed: (mouse) => {
                    builder.forceActiveFocus();
                    builder.menu = null;
                    builder.selected = card.blockKey;
                    card.moveFrom(mapToItem(board, mouse.x, mouse.y));
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        card.moveTo(mapToItem(board, mouse.x, mouse.y));

                }
                onReleased: card.moveEnd()
                onCanceled: {
                    card.dragDX = 0;
                    card.dragDY = 0;
                    builder.target = null;
                    builder.overShelf = false;
                }
            }

        }

        // a grip in each corner and on each edge's middle, shown on hover
        Repeater {
            model: [{"l": 1, "t": 1}, {"r": 1, "t": 1}, {"l": 1, "b": 1}, {"r": 1, "b": 1}, {"t": 1}, {"b": 1}, {"l": 1}, {"r": 1}]

            Rectangle {
                required property var modelData
                readonly property bool corner: !!((modelData.l || modelData.r) && (modelData.t || modelData.b))
                readonly property real len: corner ? Theme.dp(10) : Theme.dp(24)

                visible: hover.hovered || card.sizing
                z: 4
                width: modelData.l || modelData.r ? (corner ? len : Theme.dp(5)) : len
                height: modelData.t || modelData.b ? (corner ? len : Theme.dp(5)) : len
                x: modelData.l ? -width / 2 : (modelData.r ? card.width - width / 2 : (card.width - width) / 2)
                y: modelData.t ? -height / 2 : (modelData.b ? card.height - height / 2 : (card.height - height) / 2)
                radius: Math.min(width, height) / 2
                color: Theme.accent
            }

        }

        // the edges and corners themselves: a strip along each, a square at each corner
        Repeater {
            model: [{"l": 1, "t": 1}, {"r": 1, "t": 1}, {"l": 1, "b": 1}, {"r": 1, "b": 1}, {"t": 1}, {"b": 1}, {"l": 1}, {"r": 1}]

            MouseArea {
                required property var modelData
                readonly property real e: Theme.dp(12)

                z: 5
                width: modelData.l || modelData.r ? e : card.width - e * 2
                height: modelData.t || modelData.b ? e : card.height - e * 2
                x: modelData.l ? -e / 2 : (modelData.r ? card.width - e / 2 : e)
                y: modelData.t ? -e / 2 : (modelData.b ? card.height - e / 2 : e)
                preventStealing: true
                cursorShape: (modelData.l || modelData.r) && (modelData.t || modelData.b) ? ((!!modelData.l === !!modelData.t) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : (modelData.l || modelData.r ? Qt.SizeHorCursor : Qt.SizeVerCursor)
                onPressed: {
                    builder.forceActiveFocus();
                    builder.menu = null;
                    builder.selected = card.blockKey;
                    card.sizing = true;
                    builder.sizing = true;
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        card.sizeTo(mapToItem(board, mouse.x, mouse.y), modelData);

                }
                onReleased: card.sizeEnd()
                onCanceled: {
                    card.sizing = false;
                    builder.sizing = false;
                    builder.target = null;
                }
            }

        }

    }

    // a small button on a block's name tag
    component TagButton: Rectangle {
        id: tb

        property string icon: ""

        signal clicked()

        anchors.verticalCenter: parent.verticalCenter
        width: Theme.dp(24)
        height: Theme.dp(24)
        radius: width / 2
        color: tbArea.containsMouse ? Theme.alpha(Theme.fgAccent, 0.16) : "transparent"

        Icon {
            anchors.centerIn: parent
            name: tb.icon
            size: Theme.dp(16)
            color: Theme.fgAccent
        }

        MouseArea {
            id: tbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tb.clicked()
        }

    }

    // one look of a block, the block drawn in it at the width it has on the
    // grid, with its name; the one in use is ticked. as a picker it is the
    // block in the look it has, and a click picks the block
    component LookTile: Item {
        id: lt

        property string block: ""
        property var look: null
        property bool picker: false
        readonly property bool on: !lt.picker && !!lt.look && Prefs.systemBlockStyle(lt.block) === lt.look.key
        readonly property var cell: builder.place[lt.block] || null

        width: Theme.dp(176)
        height: Theme.dp(150)

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: ltArea.containsMouse && !lt.on ? Theme.withBlur(Theme.surfaceHighest) : Theme.withBlur(Theme.surfaceHigh)
            border.width: lt.on ? Theme.dp(2) : 0
            border.color: Theme.accent
        }

        Item {
            id: ltStage

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(10)
            height: parent.height - Theme.dp(42)

            Item {
                anchors.centerIn: parent
                width: ltPreview.width * ltPreview.scale
                height: Math.min(parent.height, ltPreview.height * ltPreview.scale)
                clip: true

                CcBlock {
                    id: ltPreview

                    enabled: false
                    scale: Math.min(ltStage.width / width, ltStage.height / height, 1)
                    transformOrigin: Item.TopLeft
                    width: builder.span(lt.cell ? lt.cell.w : 6)
                    height: implicitHeight
                    kind: lt.block
                    keys: builder.keysOf(lt.block)
                    host: sample
                    cols: lt.cell ? lt.cell.w : 6
                    bigCols: lt.cell ? Math.max(1, Math.floor(lt.cell.w / 3)) : 2
                    gap: builder.gridGap
                    standing: lt.block === "sliders" && builder.slidersStand
                    look: lt.look ? lt.look.key : ""
                    cards: Prefs.systemBlockCards
                }

            }

        }

        LText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(10)
            role: "labelLarge"
            text: lt.picker ? builder.blockName(lt.block) + (lt.look ? " · " + lt.look.name : "") : (lt.look ? lt.look.name : "")
            elide: Text.ElideRight
        }

        // in use
        Rectangle {
            visible: lt.on
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(6)
            width: Theme.dp(22)
            height: Theme.dp(22)
            radius: width / 2
            color: Theme.primary

            Icon {
                anchors.centerIn: parent
                name: "check"
                size: Theme.dp(14)
                color: Theme.fgPrimary
            }

        }

        MouseArea {
            id: ltArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: lt.on ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (lt.picker) {
                    builder.forceActiveFocus();
                    builder.selected = lt.block;
                } else if (lt.look) {
                    Prefs.setSystemBlockStyle(lt.block, lt.look.key);
                }
            }
        }

    }

    // one thing on the shelf, drawn as the panel draws it, with its name. a
    // block already on the panel is shown faded, with a check
    component ShelfItem: Item {
        id: si

        property var item: null
        readonly property string kind: si.item ? si.item.kind : ""
        readonly property bool on: !!si.item && si.item.on

        width: si.kind === "block" ? Theme.dp(176) : (si.kind === "slider" ? Theme.dp(208) : (si.kind === "gauge" ? Theme.dp(112) : Theme.dp(92)))
        height: si.kind === "block" ? Theme.dp(148) : (si.kind === "slider" ? Theme.dp(92) : (si.kind === "gauge" ? Theme.dp(150) : Theme.dp(104)))

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: siArea.containsMouse && !si.on ? Theme.withBlur(Theme.surfaceHighest) : Theme.withBlur(Theme.surfaceHigh)
            opacity: si.on ? 0.5 : 1
        }

        Item {
            id: stage

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(10)
            height: si.kind === "tile" ? parent.height - Theme.dp(20) : parent.height - Theme.dp(40)
            opacity: si.on ? 0.45 : 1
            clip: si.kind === "block"

            // a small tile carries its own name under it
            CcSmallTile {
                visible: si.kind === "tile"
                enabled: false
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(52)
                gutter: Theme.dp(16)
                icon: si.item ? si.item.icon : ""
                label: si.item ? si.item.name : ""
            }

            CcLyingSlider {
                visible: si.kind === "slider"
                enabled: false
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                icon: si.item ? si.item.icon : ""
                value: 55
            }

            CcGauge {
                visible: si.kind === "gauge"
                enabled: false
                anchors.centerIn: parent
                width: parent.width
                value: 0.55
                // its icon in the ring, the name being under the card
                center: ""
                centerIcon: si.item ? si.item.icon : ""
                label: ""
            }

            // a block, as it would sit six columns wide, scaled to fit
            Item {
                visible: si.kind === "block"
                anchors.centerIn: parent
                width: preview.width * preview.scale
                height: Math.min(parent.height, preview.height * preview.scale)
                clip: true

                CcBlock {
                    id: preview

                    enabled: false
                    scale: Math.min(stage.width / width, 1)
                    transformOrigin: Item.TopLeft
                    width: builder.span(6)
                    height: implicitHeight
                    kind: si.kind === "block" ? si.item.key : ""
                    keys: si.kind === "block" ? builder.keysOf(si.item.key) : []
                    host: sample
                    cols: 6
                    bigCols: 2
                    gap: builder.gridGap
                    look: si.kind === "block" ? Prefs.systemBlockStyle(si.item.key) : ""
                    cards: Prefs.systemBlockCards
                }

            }

        }

        LText {
            visible: si.kind !== "tile"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Theme.dp(10)
            role: "labelLarge"
            text: si.item ? si.item.name : ""
            elide: Text.ElideRight
        }

        // on the panel already
        Rectangle {
            visible: si.on
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(6)
            width: Theme.dp(22)
            height: Theme.dp(22)
            radius: width / 2
            color: Theme.primary

            Icon {
                anchors.centerIn: parent
                name: "check"
                size: Theme.dp(14)
                color: Theme.fgPrimary
            }

        }

        MouseArea {
            id: siArea

            property point start
            property bool carrying: false

            anchors.fill: parent
            enabled: !si.on
            hoverEnabled: true
            preventStealing: true
            cursorShape: siArea.carrying ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: (mouse) => {
                siArea.start = Qt.point(mouse.x, mouse.y);
                siArea.carrying = false;
            }
            onPositionChanged: (mouse) => {
                if (!pressed)
                    return ;

                if (!siArea.carrying) {
                    if (Math.abs(mouse.x - siArea.start.x) + Math.abs(mouse.y - siArea.start.y) < Theme.dp(8))
                        return ;

                    siArea.carrying = true;
                    builder.carryStart(si.item, mapToItem(builder, mouse.x, mouse.y));
                }
                builder.carryTo(mapToItem(builder, mouse.x, mouse.y));
            }
            onReleased: {
                if (siArea.carrying)
                    builder.carryEnd();
                else
                    builder.addItem(si.item);
                siArea.carrying = false;
            }
            onCanceled: {
                builder.carry = null;
                builder.target = null;
                builder.drop = null;
                siArea.carrying = false;
            }
        }

    }

}
