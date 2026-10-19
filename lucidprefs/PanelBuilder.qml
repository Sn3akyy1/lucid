import QtQuick
import qs
import qs.lucidcc
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, big tiles,
// tiles, media, gauges) on the panel's own grid, bento style. each is the
// panel's own CcBlock with made-up readings, drawn full size and the whole
// grid scaled down to fit, so it reads as the panel does. a block is dragged
// by anything but its pieces, or by its name, to any cell and stretched by any
// edge or corner; the bar above names each, with its + to put pieces back, its
// eye to hide it and, for the sliders, whether they stand or lie. inside a
// block the pieces are dragged into order and taken out with their cross; a
// tile is dragged, or tapped, across to the other kind of tile
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
        return builder.spareOf(block).map((k) => {
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

    function shelfCount(tab) {
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

    width: parent ? parent.width : 0
    implicitHeight: boardWrap.y + boardWrap.height
    // the three blocks there were once are written out as the five
    Component.onCompleted: Prefs.systemMigrate()

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
            return k === "wifi" ? "Connected" : (k === "bluetooth" ? "On" : "Off");
        }

        function tileChecked(k) {
            return k === "wifi" || k === "bluetooth";
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

        function gauge(k) {
            const e = builder.entryOf("gauges", k);
            const v = {
                "cpu": [0.28, "62 °C"],
                "ram": [0.62, "9.4 GB"],
                "disk": [0.38, "297 GB free"],
                "battery": [0.8, "Full"]
            }[k] || [0.5, ""];
            return {
                "value": v[0],
                "center": Math.round(v[0] * 100) + "",
                "label": e ? e.name : k,
                "detail": v[1],
                "tone": Theme.accent,
                "icon": ""
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
                        onClicked: builder.tab = modelData.key
                    }

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
                text: "All of them are on the panel already."
            }

        }

    }

    // the grid, full size and scaled down as one
    Item {
        id: boardWrap

        y: shelf.height + Theme.dp(12)
        width: Math.round(board.width * builder.k)
        height: Math.round(board.height * builder.k)
        x: Math.max(0, Math.round((builder.width - width) / 2))

        Item {
            id: board

            width: builder.span(builder.boardCols)
            height: builder.rowSpan(builder.boardRows)
            scale: builder.k
            transformOrigin: Item.TopLeft

            // a faint stripe for each column
            Repeater {
                model: builder.boardCols

                Rectangle {
                    required property int index

                    x: index * builder.stepX
                    width: builder.unit
                    height: board.height
                    radius: Theme.dp(8)
                    color: Theme.alpha(Theme.text, 0.035)
                }

            }

            // where the block being carried or stretched would go
            Rectangle {
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
                builder.setBlockShown(card.blockKey, false);
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
            cards: Prefs.systemBlockCards
        }

        // and their outline, over what it holds
        Rectangle {
            readonly property bool lit: card.busy || hover.hovered || (!!builder.drop && builder.drop.card === card)

            anchors.fill: parent
            z: 2
            radius: Theme.radiusMd
            color: "transparent"
            border.width: lit ? Theme.dp(2) : Theme.dp(1)
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
            cursorShape: area.mode === 1 || area.mode === 3 ? Qt.ClosedHandCursor : (card.hovered >= 0 ? Qt.PointingHandCursor : Qt.OpenHandCursor)
            onPressed: (mouse) => {
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
                        builder.setKeys(card.blockKey, builder.keysOf(card.blockKey).filter((k) => {
                        return k !== key;
                    }));
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
                    builder.setKeys(card.blockKey, card.order.filter((k) => {
                        return k !== key;
                    }));
                }
            }

        }

        // its name, with a handle, while the pointer is on the block
        Rectangle {
            visible: hover.hovered || card.busy
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

                // off the panel, keeping what it holds; it waits on the shelf
                TagButton {
                    visible: Prefs.systemBlockKeys.length > 1
                    icon: "visibility_off"
                    onClicked: builder.setBlockShown(card.blockKey, false)
                }

            }

            MouseArea {
                id: tagArea

                z: -1
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                onPressed: (mouse) => {
                    return card.moveFrom(mapToItem(board, mouse.x, mouse.y));
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
                readonly property bool corner: (modelData.l || modelData.r) && (modelData.t || modelData.b)
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
                onPressed: card.sizing = true
                onPositionChanged: (mouse) => {
                    if (pressed)
                        card.sizeTo(mapToItem(board, mouse.x, mouse.y), modelData);

                }
                onReleased: card.sizeEnd()
                onCanceled: {
                    card.sizing = false;
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
