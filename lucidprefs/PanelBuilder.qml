import QtQuick
import qs
import qs.lucidui

// the control centre, built like bricks: its blocks (sliders, toggles, system)
// on the panel's own grid, bento style, drawn as the panel draws them. a block
// is dragged anywhere on it to any cell and stretched by any edge or corner;
// the bar above names each, with its + to put pieces back, its eye to hide it
// and, for the sliders, whether they stand or lie. inside a block the pieces
// are dragged into order and taken out with their cross; a tile is tapped to
// go big (half a row, with its name) or back to small
Item {
    id: builder

    // the panel's measures, as System.qml takes them: a column a tile wide, a
    // row a thin strip, the gap between, and the tiles' own gap
    readonly property real unit: Theme.dp(52)
    readonly property real rowUnit: Theme.dp(20)
    readonly property real gridGap: Theme.dp(12)
    readonly property real tileGap: Theme.dp(8)
    readonly property int boardCols: Prefs.systemGridCols
    // how much the grid is drawn down to fit the page
    readonly property real k: Math.max(0.3, Math.min(1, builder.width / builder.span(builder.boardCols)))
    readonly property real stepX: (builder.unit + builder.gridGap) * builder.k
    readonly property real stepY: (builder.rowUnit + builder.gridGap) * builder.k
    // across, where each block sits does not hang on what it holds
    readonly property var spots: Prefs.systemGridPlace(Prefs.systemBlockKeys)
    // the rows each card's pieces need, as the panel will need them
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
    // the block whose left-out pieces are on offer under the bar
    property string adding: ""
    // the piece being dragged, drawn under the pointer while its place shows faded
    property var ghost: null
    property point ghostAt: Qt.point(0, 0)

    function span(n) {
        return n * builder.unit + Math.max(0, n - 1) * builder.gridGap;
    }

    function rowSpan(n) {
        return n * builder.rowUnit + Math.max(0, n - 1) * builder.gridGap;
    }

    // a spot on the grid, in the board's pixels
    function boxOf(r) {
        return Qt.rect(Math.round(r.x * builder.stepX), Math.round(r.y * builder.stepY), Math.round(builder.span(r.w) * builder.k), Math.round(builder.rowSpan(r.h) * builder.k));
    }

    function freeFor(key, r) {
        return !Prefs.systemBlockKeys.some((k) => {
            return k !== key && builder.place[k] && Prefs.systemGridOverlap(r, builder.place[k]);
        });
    }

    // gauges sharing a card, as System.qml lays them: as many to a row as
    // leave each its 88, in rows as even as can be
    function gaugeCols(n, width) {
        const most = Math.max(1, Math.min(n, Math.floor(width / Theme.dp(88))));
        return Math.max(1, Math.ceil(n / Math.ceil(n / most)));
    }

    function catalogueOf(block) {
        return block === "sliders" ? Prefs.systemSliderCatalog : (block === "toggles" ? Prefs.systemTileCatalog : Prefs.systemInfoCatalog);
    }

    function keysOf(block) {
        return block === "sliders" ? Prefs.systemSliderKeys : (block === "toggles" ? Prefs.systemTileKeys : Prefs.systemInfoKeys);
    }

    function spareOf(block) {
        const keys = builder.keysOf(block);
        return builder.catalogueOf(block).map((e) => {
            return e.key;
        }).filter((k) => {
            return keys.indexOf(k) === -1;
        });
    }

    function setKeys(block, keys) {
        if (block === "sliders")
            Prefs.systemSliders = keys.join(",");
        else if (block === "toggles")
            Prefs.setSystemTiles(keys);
        else
            Prefs.systemInfo = keys.join(",");
    }

    function entryOf(block, key) {
        return builder.catalogueOf(block).find((e) => {
            return e.key === key;
        }) || null;
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
    implicitHeight: bar.height + (adds.visible ? adds.height + Theme.dp(10) : 0) + Theme.dp(12) + board.height

    // each block by name: its + for the pieces left out, the sliders' stand
    // or lie, and its eye, which hides it with all it holds or brings it back
    Flow {
        id: bar

        width: parent.width
        spacing: Theme.dp(8)

        Repeater {
            model: Prefs.systemBlockCatalog

            Rectangle {
                id: chip

                required property var modelData
                readonly property bool shown: Prefs.systemBlockKeys.indexOf(chip.modelData.key) !== -1
                readonly property bool hasSpare: builder.spareOf(chip.modelData.key).length > 0

                width: chipRow.implicitWidth + Theme.dp(18)
                height: Theme.dp(40)
                radius: height / 2
                color: chip.shown ? Theme.bgSunken : "transparent"
                border.width: chip.shown ? 0 : Theme.dp(1.5)
                border.color: Theme.outline

                Row {
                    id: chipRow

                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.dp(12)
                    spacing: Theme.dp(2)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: chip.modelData.icon
                        size: Theme.dp(18)
                        color: chip.shown ? Theme.accent : Theme.subtext
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: Theme.dp(6)
                        rightPadding: Theme.dp(4)
                        text: chip.modelData.name
                        color: chip.shown ? Theme.text : Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        font.weight: Font.DemiBold
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.shown
                        size: Theme.dp(30)
                        enabled: chip.hasSpare
                        iconPath: builder.adding === chip.modelData.key && chip.hasSpare ? "close" : "add"
                        onClicked: builder.adding = builder.adding === chip.modelData.key ? "" : chip.modelData.key
                    }

                    // the sliders stand side by side or lie one under another
                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.shown && chip.modelData.key === "sliders"
                        size: Theme.dp(30)
                        iconPath: builder.slidersStand ? "width" : "height"
                        onClicked: Prefs.systemGridSet("sliders", {
                            "lie": builder.slidersStand
                        }, builder.needs)
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        size: Theme.dp(30)
                        iconPath: chip.shown ? "visibility" : "visibility_off"
                        enabled: !chip.shown || Prefs.systemBlockKeys.length > 1
                        onClicked: {
                            if (chip.shown && builder.adding === chip.modelData.key)
                                builder.adding = "";

                            builder.setBlockShown(chip.modelData.key, !chip.shown);
                        }
                    }

                }

            }

        }

    }

    // the pieces left out of one block; tapping one puts it at the end
    Flow {
        id: adds

        readonly property var spare: builder.adding !== "" ? builder.spareOf(builder.adding) : []

        visible: adds.spare.length > 0
        y: bar.height + Theme.dp(10)
        width: parent.width
        spacing: Theme.dp(6)

        Repeater {
            model: adds.spare

            Rectangle {
                id: spareChip

                required property string modelData
                readonly property var entry: builder.entryOf(builder.adding, spareChip.modelData)

                width: Math.min(parent.width, spareRow.implicitWidth + Theme.dp(20))
                height: Theme.dp(34)
                radius: Theme.dp(12)
                color: "transparent"
                border.width: Theme.dp(1.5)
                border.color: Theme.outline
                clip: true

                Row {
                    id: spareRow

                    anchors.centerIn: parent
                    spacing: Theme.dp(6)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: spareChip.entry ? spareChip.entry.icon : ""
                        size: Theme.dp(18)
                        color: Theme.text
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: spareChip.entry ? spareChip.entry.name : spareChip.modelData
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                    }

                }

                StateLayer {
                    radius: parent.radius
                    onClicked: builder.setKeys(builder.adding, builder.keysOf(builder.adding).concat([spareChip.modelData]))
                }

            }

        }

    }

    // the grid: a faint stripe for each column, the blocks on it
    Item {
        id: board

        y: bar.height + (adds.visible ? adds.height + Theme.dp(10) : 0) + Theme.dp(12)
        width: Math.round(builder.span(builder.boardCols) * builder.k)
        height: Math.round(builder.rowSpan(builder.boardRows) * builder.k)
        x: Math.max(0, Math.round((builder.width - width) / 2))

        Repeater {
            model: builder.boardCols

            Rectangle {
                required property int index

                x: Math.round(index * builder.stepX)
                width: Math.round(builder.unit * builder.k)
                height: board.height
                radius: Theme.dp(6)
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

    // the dragged piece, over everything
    Item {
        visible: builder.ghost !== null
        x: builder.ghostAt.x - width / 2
        y: builder.ghostAt.y - height / 2
        z: 10
        width: ghostPiece.width
        height: ghostPiece.height

        Piece {
            id: ghostPiece

            block: builder.ghost ? builder.ghost.block : ""
            pieceKey: builder.ghost ? builder.ghost.key : ""
            big: builder.ghost ? builder.ghost.big : false
            width: builder.ghost ? builder.ghost.w : 0
            height: builder.ghost ? builder.ghost.h : 0
            lifted: true
        }

    }

    // a block on the grid: what it holds, as the panel draws it, filling its
    // cells. dragged by anything but its pieces it moves; its edges and
    // corners stretch it
    component BlockCard: Item {
        id: card

        property string blockKey: ""
        property bool pieceDragging: false
        // the pieces in the order shown, while one is dragged too
        property var order: []
        readonly property var entry: Prefs.systemBlockCatalog.find((b) => {
            return b.key === card.blockKey;
        })
        readonly property var keys: builder.keysOf(card.blockKey)
        readonly property var spot: builder.spots[card.blockKey] || null
        readonly property var cell: builder.place[card.blockKey] || card.spot
        readonly property rect box: card.cell ? builder.boxOf(card.cell) : Qt.rect(0, 0, 0, 0)
        // the block's width on the panel
        readonly property real realW: card.spot ? builder.span(card.spot.w) : builder.unit
        // the tiles and the standing sliders keep the grid's gap, a column each
        readonly property real pieceGap: Math.round((card.blockKey === "toggles" || card.standing ? builder.gridGap : builder.tileGap) * builder.k)
        // a column is a tile
        readonly property int tileCols: card.spot ? card.spot.w : 6
        readonly property bool standing: card.blockKey === "sliders" && builder.slidersStand
        // what the pieces need down, on the panel: the standing sliders their
        // least, the system block's cards the panel's wider gap between them
        readonly property real needReal: {
            if (card.standing)
                return Theme.dp(160);

            const extra = card.blockKey === "system" ? Math.max(0, card.runs.length + card.order.filter((k) => {
                return k === "media";
            }).length - 1) * Theme.dp(4) : 0;
            return pieceFlow.implicitHeight / builder.k + extra;
        }
        readonly property int needRows: Math.max(1, Math.ceil((card.needReal + builder.gridGap) / (builder.rowUnit + builder.gridGap)))
        readonly property bool busy: moveArea.pressed || tagArea.pressed || card.sizing
        property bool sizing: false
        // how far the pointer has carried this block
        property real dragDX: 0
        property real dragDY: 0
        // where on the card the pointer took hold of it
        property point grab

        function syncPieces() {
            if (card.pieceDragging)
                return ;

            const now = [];
            for (let i = 0; i < pieceModel.count; i++) now.push(pieceModel.get(i).key)
            if (now.join(",") === card.keys.join(",")) {
                card.order = now;
                return ;
            }
            pieceModel.clear();
            for (const k of card.keys) pieceModel.append({
                "key": k
            })
            card.order = card.keys.slice();
        }

        function readOrder() {
            const l = [];
            for (let i = 0; i < pieceModel.count; i++) l.push(pieceModel.get(i).key)
            card.order = l;
            return l;
        }

        // the piece slot under a point given in the pieces' flow, or -1
        function pieceAt(p) {
            for (let i = 0; i < pieceRepeater.count; i++) {
                const it = pieceRepeater.itemAt(i);
                if (it && p.x >= it.x && p.x < it.x + it.width + pieceFlow.spacing && p.y >= it.y && p.y < it.y + it.height + pieceFlow.spacing)
                    return i;

            }
            return -1;
        }

        // the system block reads as cards: a run of gauges shares a row, as
        // many to it as the block's width allows
        function gaugeRun(i) {
            let a = i, b = i;
            while (a > 0 && card.order[a - 1] !== "media")
                a--;
            while (b < card.order.length - 1 && card.order[b + 1] !== "media")
                b++;
            return b - a + 1;
        }

        function gaugeCols(i) {
            return builder.gaugeCols(card.gaugeRun(i), card.realW - Theme.dp(16));
        }

        function pieceW(key, big, i) {
            if (card.blockKey === "toggles") {
                if (big)
                    return Math.floor((card.width - card.pieceGap) / 2);

                return Math.floor((card.width - card.pieceGap * (card.tileCols - 1)) / card.tileCols);
            }
            if (card.blockKey === "sliders") {
                const n = Math.max(1, card.keys.length);
                return card.standing ? Math.floor((card.width - card.pieceGap * (n - 1)) / n) : card.width;
            }
            if (key === "media")
                return card.width;

            const n = Math.max(1, card.gaugeCols(i));
            return Math.floor((card.width - card.pieceGap * (n - 1)) / n);
        }

        function pieceH(key, big, i) {
            if (card.blockKey === "toggles")
                return big ? Math.round(Theme.dp(64) * builder.k) : card.pieceW(key, big, i) + Math.round(Theme.dp(24) * builder.k);

            if (card.blockKey === "sliders")
                return card.standing ? card.height : Math.round(Theme.dp(50) * builder.k);

            if (key === "media")
                return Math.round(Theme.dp(84) * builder.k);

            // a gauge: its ring, as wide as its share allows, with its two
            // lines under it, and its share of the card's padding and the
            // panel's wider gap between rows
            const real = card.pieceW(key, big, i) / builder.k;
            const rows = Math.ceil(card.gaugeRun(i) / card.gaugeCols(i));
            const ring = Math.max(Theme.dp(54), Math.min(Theme.dp(84), real - Theme.dp(20)));
            return Math.round((ring + Theme.dp(38) + (Theme.dp(28) + Theme.dp(4) * (rows - 1)) / rows) * builder.k);
        }

        // carrying the block: the card follows the pointer, its outline snaps to a cell
        function moveFrom(p) {
            card.grab = Qt.point(p.x - card.x, p.y - card.y);
        }

        function moveTo(p) {
            const left = p.x - card.grab.x, top = p.y - card.grab.y;
            card.dragDX = left - card.box.x;
            card.dragDY = top - card.box.y;
            builder.target = {
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
            if (t && (t.x !== card.cell.x || t.y !== card.cell.y))
                Prefs.systemGridSet(card.blockKey, {
                "x": t.x,
                "y": t.y
            }, builder.needs);

        }

        // stretching it by an edge or corner, in whole cells, no smaller than
        // it needs and as far as the blocks around leave room
        function sizeTo(p, e) {
            const c = card.cell;
            let x = c.x, y = c.y, w = c.w, h = c.h;
            const minH = card.needRows;
            // in widths the block can take, and inside the grid
            const snap = (want, room) => {
                let v = Prefs.systemGridSnapW(card.blockKey, c.lie, want);
                while (v > room && v > Prefs.systemGridMinW(card.blockKey, c.lie))
                    v = Prefs.systemGridSnapW(card.blockKey, c.lie, v - 1);
                return v;
            };
            if (e.r)
                w = snap(Math.round((p.x + builder.gridGap * builder.k) / builder.stepX) - x, builder.boardCols - x);

            if (e.l) {
                const right = c.x + c.w;
                w = snap(right - Math.round(p.x / builder.stepX), right);
                x = right - w;
            }
            if (e.b)
                h = Math.max(minH, Math.round((p.y + builder.gridGap * builder.k) / builder.stepY) - y);

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
            if (t && (t.x !== c.x || t.y !== c.y || t.w !== c.w || t.h !== c.h))
                Prefs.systemGridSet(card.blockKey, t, builder.needs);

        }

        // where each run of gauges sits, for the card it shares drawn behind it
        readonly property var runs: {
            if (card.blockKey !== "system")
                return [];

            const out = [];
            let y = 0;
            let i = 0;
            while (i < card.order.length) {
                if (card.order[i] === "media") {
                    y += card.pieceH("media", false, i) + card.pieceGap;
                    i++;
                    continue;
                }
                let j = i;
                while (j < card.order.length && card.order[j] !== "media")
                    j++;
                const rows = Math.ceil((j - i) / card.gaugeCols(i));
                const h = rows * card.pieceH(card.order[i], false, i) + (rows - 1) * card.pieceGap;
                out.push({
                    "y": y,
                    "h": h
                });
                y += h + card.pieceGap;
                i = j;
            }
            return out;
        }

        onKeysChanged: card.syncPieces()
        Component.onCompleted: card.syncPieces()
        x: card.box.x + card.dragDX
        y: card.box.y + card.dragDY
        // its width from its columns alone; down, the rows decide
        width: card.spot ? Math.round(builder.span(card.spot.w) * builder.k) : 0
        height: card.box.height
        z: card.busy ? 5 : 0

        HoverHandler {
            id: hover
        }

        ListModel {
            id: pieceModel
        }

        // its cells, so the room it was given shows past what it holds
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.alpha(Theme.text, card.busy ? 0.08 : 0.04)
        }

        // and their outline, over what it holds
        Rectangle {
            anchors.fill: parent
            z: 2
            radius: Theme.radiusMd
            color: "transparent"
            border.width: card.busy || hover.hovered ? Theme.dp(1.5) : Theme.dp(1)
            border.color: card.busy || hover.hovered ? Theme.accent : Theme.alpha(Theme.text, 0.1)
        }

        // anything but a piece carries the block
        MouseArea {
            id: moveArea

            anchors.fill: parent
            hoverEnabled: true
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
            }
        }

        // what the block holds, on the panel's grid
        Repeater {
            model: card.runs

            Rectangle {
                required property var modelData

                y: modelData.y
                width: card.width
                height: modelData.h
                radius: Math.round(Theme.dp(20) * builder.k)
                color: Theme.withBlur(Theme.surfaceHigh)
            }

        }

        Flow {
            id: pieceFlow

            width: card.width
            spacing: card.pieceGap

            Repeater {
                id: pieceRepeater

                model: pieceModel

                Item {
                    id: slotItem

                    required property string key
                    required property int index
                    readonly property bool big: card.blockKey === "toggles" && Prefs.systemBigKeys.indexOf(key) !== -1
                    readonly property bool held: builder.ghost !== null && builder.ghost.key === key && builder.ghost.block === card.blockKey
                    // the last slider or card stays; a block can be hidden instead
                    readonly property bool removable: card.blockKey === "toggles" || card.keys.length > 1

                    width: card.pieceW(key, big, index)
                    height: card.pieceH(key, big, index)

                    Piece {
                        anchors.fill: parent
                        block: card.blockKey
                        pieceKey: slotItem.key
                        big: slotItem.big
                        opacity: slotItem.held ? 0.25 : 1
                    }

                    // a tap switches a tile's size; a drag moves the piece
                    MouseArea {
                        id: pieceArea

                        property point start
                        property bool moved: false

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        preventStealing: true
                        onPressed: (mouse) => {
                            start = Qt.point(mouse.x, mouse.y);
                            moved = false;
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed)
                                return ;

                            if (!moved && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) < Theme.dp(6))
                                return ;

                            if (!moved) {
                                moved = true;
                                card.pieceDragging = true;
                                builder.ghost = {
                                    "block": card.blockKey,
                                    "key": slotItem.key,
                                    "big": slotItem.big,
                                    "w": slotItem.width,
                                    "h": slotItem.height
                                };
                            }
                            builder.ghostAt = mapToItem(builder, mouse.x, mouse.y);
                            const to = card.pieceAt(mapToItem(pieceFlow, mouse.x, mouse.y));
                            if (to >= 0 && to !== slotItem.index) {
                                pieceModel.move(slotItem.index, to, 1);
                                card.readOrder();
                            }
                        }
                        onReleased: {
                            if (moved) {
                                builder.ghost = null;
                                card.pieceDragging = false;
                                builder.setKeys(card.blockKey, card.readOrder());
                            } else if (card.blockKey === "toggles") {
                                Prefs.setTileBig(slotItem.key, !slotItem.big);
                            }
                            moved = false;
                        }
                        onCanceled: {
                            builder.ghost = null;
                            card.pieceDragging = false;
                            moved = false;
                            card.syncPieces();
                        }
                    }

                    // its cross, while the pointer is on it
                    Rectangle {
                        visible: slotItem.removable && builder.ghost === null && (pieceArea.containsMouse || crossArea.containsMouse)
                        // inside a standing slider, which reaches the block's top edge
                        x: slotItem.width - width + (card.standing ? -Theme.dp(4) : Theme.dp(4))
                        y: card.standing ? Theme.dp(4) : -Theme.dp(4)
                        width: Theme.dp(18)
                        height: Theme.dp(18)
                        radius: width / 2
                        color: Theme.error

                        Icon {
                            anchors.centerIn: parent
                            name: "close"
                            size: Theme.dp(12)
                            color: Theme.fgError
                        }

                        MouseArea {
                            id: crossArea

                            anchors.fill: parent
                            anchors.margins: -Theme.dp(3)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: builder.setKeys(card.blockKey, card.keys.filter((k) => {
                                return k !== slotItem.key;
                            }))
                        }

                    }

                }

            }

        }

        // its name, with a handle, while the pointer is on the block
        Rectangle {
            visible: hover.hovered || card.busy
            x: Theme.dp(4)
            y: Theme.dp(4)
            z: 3
            width: tagRow.implicitWidth + Theme.dp(14)
            height: Theme.dp(26)
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
                    text: card.entry ? card.entry.name : card.blockKey
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: Font.DemiBold
                }

            }

            MouseArea {
                id: tagArea

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
                }
            }

        }

        // a grip in each corner and on each edge's middle, shown on hover
        Repeater {
            model: [{"l": 1, "t": 1}, {"r": 1, "t": 1}, {"l": 1, "b": 1}, {"r": 1, "b": 1}, {"t": 1}, {"b": 1}, {"l": 1}, {"r": 1}]

            Rectangle {
                required property var modelData
                readonly property bool corner: (modelData.l || modelData.r) && (modelData.t || modelData.b)
                readonly property real len: corner ? Theme.dp(8) : Theme.dp(18)

                visible: hover.hovered || card.sizing
                z: 4
                width: modelData.l || modelData.r ? (corner ? len : Theme.dp(4)) : len
                height: modelData.t || modelData.b ? (corner ? len : Theme.dp(4)) : len
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
                readonly property real e: Theme.dp(10)

                z: 5
                width: modelData.l || modelData.r ? e : card.width - e * 2
                height: modelData.t || modelData.b ? e : card.height - e * 2
                x: modelData.l ? -e / 2 : (modelData.r ? card.width - e / 2 : e)
                y: modelData.t ? -e / 2 : (modelData.b ? card.height - e / 2 : e)
                hoverEnabled: true
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

    // one piece, drawn as the panel draws it: a round tile with its name under
    // it or a big one with the name inside, a slider lying or standing, the
    // media card or a gauge
    component Piece: Item {
        id: pc

        property string block: ""
        property string pieceKey: ""
        property bool big: false
        property bool lifted: false
        readonly property var entry: builder.entryOf(pc.block, pc.pieceKey)
        readonly property string look: {
            if (pc.block === "toggles")
                return pc.big ? "big" : "tile";

            if (pc.block === "sliders")
                return builder.slidersStand ? "standing" : "lying";

            return pc.pieceKey === "media" ? "media" : "gauge";
        }
        readonly property string name: pc.entry ? pc.entry.name : pc.pieceKey
        readonly property string icon: pc.entry ? pc.entry.icon : ""
        readonly property real iconSize: Math.max(Theme.dp(14), Math.round(Theme.dp(20) * builder.k))

        // a small tile: a circle, its name in the gap under it
        Rectangle {
            id: tileFace

            visible: pc.look === "tile"
            width: pc.width
            height: pc.width
            radius: width / 2
            color: Theme.withBlur(Theme.surfaceHighest)
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent

            Icon {
                anchors.centerIn: parent
                name: pc.icon
                size: pc.iconSize
                color: Theme.text
            }

        }

        Text {
            visible: pc.look === "tile"
            anchors.top: tileFace.bottom
            anchors.topMargin: Theme.dp(2)
            width: pc.width + Theme.dp(6)
            x: -Theme.dp(3)
            horizontalAlignment: Text.AlignHCenter
            text: pc.name
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelSm
            elide: Text.ElideRight
        }

        // a big tile, the lying slider and the media card: a bar with the name in it
        Rectangle {
            visible: pc.look === "big" || pc.look === "lying" || pc.look === "media"
            width: pc.width
            height: pc.look === "lying" ? Math.round(Theme.dp(38) * builder.k) : pc.height
            anchors.verticalCenter: parent.verticalCenter
            radius: Math.round((pc.look === "big" ? Theme.dp(18) : Theme.dp(12)) * builder.k)
            color: pc.look === "big" ? Theme.primary : Theme.withBlur(pc.look === "media" ? Theme.surfaceHigh : Theme.surfaceHighest)
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent
            clip: true

            // the lying slider shows its fill, as the panel's does
            Rectangle {
                visible: pc.look === "lying"
                width: parent.width * 0.55
                height: parent.height
                radius: parent.radius
                color: Theme.alpha(Theme.primary, 0.35)
            }

            // the media card's cover
            Rectangle {
                id: cover

                visible: pc.look === "media"
                x: Math.round(Theme.dp(10) * builder.k)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(Theme.dp(64) * builder.k)
                height: width
                radius: Math.round(Theme.dp(12) * builder.k)
                color: Theme.withBlur(Theme.surfaceHighest)

                Icon {
                    anchors.centerIn: parent
                    name: pc.icon
                    size: pc.iconSize
                    color: Theme.subtext
                }

            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: pc.look === "media" ? cover.x + cover.width + Math.round(Theme.dp(12) * builder.k) : Math.round(Theme.dp(12) * builder.k)
                width: parent.width - x - Theme.dp(6)
                spacing: Theme.dp(8)

                Icon {
                    id: barIcon

                    visible: pc.look !== "media"
                    anchors.verticalCenter: parent.verticalCenter
                    name: pc.icon
                    size: pc.iconSize
                    color: pc.look === "big" ? Theme.fgPrimary : Theme.text
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (barIcon.visible ? barIcon.width + parent.spacing : 0)
                    text: pc.name
                    color: pc.look === "big" ? Theme.fgPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelLg
                    font.weight: pc.look === "big" ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

            }

        }

        // the standing slider: filled from the foot, its icon at the bottom
        Rectangle {
            visible: pc.look === "standing"
            anchors.fill: parent
            radius: Math.round(Theme.dp(16) * builder.k)
            color: Theme.withBlur(Theme.surfaceHighest)
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent
            clip: true

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.55
                radius: parent.radius
                color: Theme.alpha(Theme.primary, 0.35)
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(Theme.dp(12) * builder.k)
                name: pc.icon
                size: pc.iconSize
                color: Theme.text
            }

        }

        // a gauge: its ring, its name under it, on the card the run shares
        Rectangle {
            visible: pc.look === "gauge"
            anchors.fill: parent
            radius: Math.round(Theme.dp(16) * builder.k)
            color: pc.lifted ? Theme.withBlur(Theme.surfaceHigh) : "transparent"
            border.width: pc.lifted ? Theme.dp(1.5) : 0
            border.color: Theme.accent

            Rectangle {
                id: ring

                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(Theme.dp(12) * builder.k)
                // as the panel sizes it: its share less 20, from 54 up to 84
                width: Math.round(Math.max(Theme.dp(54), Math.min(Theme.dp(84), parent.width / builder.k - Theme.dp(20))) * builder.k)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(Theme.dp(3), Math.round(width * 0.1))
                border.color: Theme.alpha(Theme.accent, 0.55)

                Icon {
                    anchors.centerIn: parent
                    name: pc.icon
                    size: Math.round(ring.width * 0.36)
                    color: Theme.text
                }

            }

            Text {
                anchors.top: ring.bottom
                anchors.topMargin: Theme.dp(3)
                width: parent.width - Theme.dp(4)
                x: Theme.dp(2)
                horizontalAlignment: Text.AlignHCenter
                text: pc.name
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                elide: Text.ElideRight
            }

        }

    }

}
